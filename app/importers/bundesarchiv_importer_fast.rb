# Optimized streaming importer:
# - Large batch inserts (5000 records)
# - Raw SQL for bulk inserts
# - Aggressive SQLite tuning (synchronous=OFF, journal_mode=MEMORY)

class BundesarchivImporterFast
  BATCH_SIZE = 5000

  def initialize(dir)
    @dir = dir || "data"
    @node_cache = {}
    @origin_cache = {}
    @file_count = 0
    @pending_files = []
    @conn = nil
  end

  def run(show_progress: false)
    $stdout.sync = true
    puts "Importing data from XML files in #{@dir}..." if show_progress
    start = Time.now

    @conn = ActiveRecord::Base.connection
    configure_sqlite_for_bulk_import

    xml_files = Dir.glob("*.xml", base: @dir).sort
    total_files = xml_files.count

    last_report = start
    xml_files.each_with_index do |filename, index|
      process_file(filename)

      # Flush batch if large enough
      if @pending_files.size >= BATCH_SIZE
        flush_batch
      end

      # Progress report every 2 seconds
      if show_progress && (Time.now - last_report) >= 2
        elapsed = Time.now - start
        files_done = index + 1
        rate = files_done / elapsed
        eta = format_duration((total_files - files_done) / rate)
        puts "  #{files_done}/#{total_files} files (#{rate.round(1)}/s) - #{@file_count} records - ETA: #{eta}"
        last_report = Time.now
      end
    end

    # Flush remaining
    flush_batch if @pending_files.any?

    restore_sqlite_settings
    ArchiveFile.update_cached_all_count

    elapsed = Time.now - start
    if show_progress
      puts "\nFinished. Imported #{@file_count} archive files in #{format_duration(elapsed)}."
      puts "Overall speed: #{(@file_count / elapsed).round(1)} records/s, #{(total_files / elapsed).round(1)} files/s"
    end
  end

  private

  def format_duration(seconds)
    return "0s" if seconds <= 0
    hours = (seconds / 3600).to_i
    minutes = ((seconds % 3600) / 60).to_i
    secs = (seconds % 60).to_i
    parts = []
    parts << "#{hours}h" if hours > 0
    parts << "#{minutes}m" if minutes > 0 || hours > 0
    parts << "#{secs}s"
    parts.join(" ")
  end

  def configure_sqlite_for_bulk_import
    @conn.execute("PRAGMA cache_size = -65536") # 64MB
    @conn.execute("PRAGMA synchronous = OFF")
    @conn.execute("PRAGMA journal_mode = MEMORY")
    @conn.execute("PRAGMA temp_store = MEMORY")
    @conn.execute("PRAGMA mmap_size = 268435456") # 256MB
  end

  def restore_sqlite_settings
    @conn.execute("PRAGMA synchronous = NORMAL")
    @conn.execute("PRAGMA journal_mode = DELETE")
    @conn.execute("PRAGMA cache_size = -2000")
  end

  def process_file(filename)
    path = File.join(@dir, filename)
    doc = File.open(path) { |f| Nokogiri.XML(f) }
    doc.remove_namespaces!

    archive_description = doc.at_xpath("/ead/archdesc")
    return unless archive_description&.attr("type") == "inventory"

    archive_description.xpath("//c[@level='fonds']").each do |fond|
      process_hierarchy(fond, [])
    end
  end

  def process_hierarchy(node, parent_nodes)
    archive_node = get_or_create_node(node, parent_nodes)
    current_parents = parent_nodes + [archive_node]

    # Collect files at this level
    node.xpath("c[@level='file']").each do |file_node|
      @pending_files << extract_file_data(file_node, current_parents)
    end

    # Recurse into children
    node.xpath("c[@level!='file']").each do |child|
      process_hierarchy(child, current_parents)
    end
  end

  def get_or_create_node(node, parent_nodes)
    source_id = node.attr("id")
    return @node_cache[source_id] if @node_cache[source_id]

    archive_node = ArchiveNode.find_or_initialize_by(source_id: source_id)
    archive_node.assign_attributes(
      name: node.at_xpath("did/unittitle")&.text,
      level: node.attr("level"),
      parent_node: parent_nodes.last
    )
    archive_node.save! if archive_node.new_record? || archive_node.changed?
    @node_cache[source_id] = archive_node
    archive_node
  end

  def extract_file_data(node, parent_nodes)
    date_node = node.at_xpath("did/unitdate")
    date = UnitDate.new(date_node)

    origins = node.xpath("did/origination").map do |origin|
      { name: origin.text, label: origin.attr("label") }
    end

    call_number = node.at_xpath('did/unitid[@type="call number"]')&.text&.sub(/\ABArch /, "") || ""

    parent_chain = parent_nodes.map { |n| { "name" => n.name, "id" => n.id } }

    {
      archive_node: parent_nodes.last,
      title: node.at_xpath("did/unittitle")&.text,
      call_number: call_number,
      source_date_text: date.text,
      source_date_start: date.start_date,
      source_date_end: date.end_date,
      source_id: node.attr("id"),
      link: node.at_xpath("otherfindaid/p/extref")&.attr("href"),
      location: node.at_xpath("did/physloc")&.text,
      language_code: node.at_xpath("did/langmaterial/language")&.attr("langcode"),
      summary: node.at_xpath('scopecontent[@encodinganalog="summary"]/p')&.text,
      origins: origins,
      parents_json: parent_chain.to_json
    }
  end

  def flush_batch
    return if @pending_files.empty?

    now = Time.current.iso8601
    all_originations = []

    ActiveRecord::Base.transaction do
      # Build all values
      values = @pending_files.map do |f|
        [
          f[:archive_node].id,
          @conn.quote(f[:title]),
          @conn.quote(f[:summary]),
          @conn.quote(f[:call_number]),
          @conn.quote(f[:source_date_text]),
          f[:source_date_start] ? @conn.quote(f[:source_date_start].to_s) : "NULL",
          f[:source_date_end] ? @conn.quote(f[:source_date_end].to_s) : "NULL",
          @conn.quote(f[:source_id]),
          @conn.quote(f[:link]),
          @conn.quote(f[:location]),
          @conn.quote(f[:language_code]),
          @conn.quote(f[:parents_json]),
          @conn.quote(now),
          @conn.quote(now)
        ].join(",")
      end

      # Insert in chunks to avoid SQL size limits
      file_index = 0
      values.each_slice(1000) do |chunk|
        sql = <<~SQL
          INSERT INTO archive_files
            (archive_node_id, title, summary, call_number, source_date_text,
             source_date_start, source_date_end, source_id, link, location,
             language_code, parents, created_at, updated_at)
          VALUES #{chunk.map { |v| "(#{v})" }.join(",")}
          ON CONFLICT(source_id) DO UPDATE SET
            archive_node_id = excluded.archive_node_id,
            title = excluded.title,
            summary = excluded.summary,
            call_number = excluded.call_number,
            source_date_text = excluded.source_date_text,
            source_date_start = excluded.source_date_start,
            source_date_end = excluded.source_date_end,
            link = excluded.link,
            location = excluded.location,
            language_code = excluded.language_code,
            parents = excluded.parents,
            updated_at = excluded.updated_at
          RETURNING id, source_id
        SQL

        results = @conn.execute(sql)
        id_map = results.to_h { |r| [r["source_id"], r["id"]] }

        # Collect originations for this chunk
        chunk.size.times do
          file_data = @pending_files[file_index]
          file_id = id_map[file_data[:source_id]]
          file_index += 1
          next unless file_id

          file_data[:origins]&.each do |origin_attrs|
            origin = get_or_create_origin(origin_attrs[:name], origin_attrs[:label])
            all_originations << { archive_file_id: file_id, origin_id: origin.id }
          end
        end
      end

      # Batch insert originations
      all_originations.each_slice(2000) do |batch|
        Origination.insert_all(batch, unique_by: [:archive_file_id, :origin_id])
      end
    end

    @file_count += @pending_files.size
    @pending_files.clear
  end

  def get_or_create_origin(name, label)
    key = [name, label]
    return @origin_cache[key] if @origin_cache[key]

    origin = Origin.find_or_create_by(name: name, label: label)
    @origin_cache[key] = origin
    origin
  end
end
