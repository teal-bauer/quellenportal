class ArchiveObject
  def initialize(parent_nodes, node, caches)
    @parent_nodes = parent_nodes
    @node = node
    @caches = caches
    @archive_node = store
  end

  def store
    source_id = @node.attr("id")
    return @caches[:nodes][source_id] if @caches[:nodes][source_id]

    node = ArchiveNode.find_or_initialize_by(source_id: source_id)
    node.assign_attributes(
      name: @node.xpath("did/unittitle").text,
      level: @node.attr("level"),
      parent_node: @parent_nodes.last
    )
    node.save! if node.new_record? || node.changed?
    @caches[:nodes][source_id] = node
    node
  end

  def process_files
    file_nodes = @node.xpath("c[@level='file']")
    return 0 if file_nodes.empty?

    archive_file_count = 0
    originations_to_insert = []

    file_nodes.each_slice(1000) do |slice|
      origin_data = []
      data = slice.map do |node|
        date = UnitDate.new(node.xpath("did/unitdate").first)

        node_origins = node.xpath("did/origination").map do |origin|
          { name: origin.text, label: origin.attr("label") }
        end
        origin_data << node_origins

        call_number = node
          .xpath('did/unitid[@type="call number"]')
          .text
          .sub(/\ABArch /, "")

        parents_cache = (@parent_nodes + [@archive_node]).map do |n|
          { name: n.name, id: n.id }
        end

        {
          archive_node_id: @archive_node.id,
          title: node.xpath("did/unittitle").text,
          parents: parents_cache,
          call_number: call_number,
          source_date_text: date.text,
          source_date_start: date.start_date,
          source_date_end: date.end_date,
          source_id: node.attr("id"),
          link: node.xpath("otherfindaid/p/extref")[0]&.attr("href"),
          location: node.xpath("did/physloc").text,
          language_code: node.xpath("did/langmaterial/language")[0]&.attr("langcode"),
          summary: node.xpath('scopecontent[@encodinganalog="summary"]/p').text
        }
      end

      results = ArchiveFile.upsert_all(data, unique_by: :source_id, returning: [:id, :source_id])
      id_map = results.to_h { |r| [r["source_id"], r["id"]] }

      data.zip(origin_data).each do |file_data, origins|
        file_id = id_map[file_data[:source_id]]
        origins.each do |origin_attrs|
          origin = get_or_create_origin(origin_attrs[:name], origin_attrs[:label])
          originations_to_insert << { archive_file_id: file_id, origin_id: origin.id }
        end
      end

      archive_file_count += data.count
    end

    if originations_to_insert.any?
      Origination.insert_all(originations_to_insert, unique_by: [:archive_file_id, :origin_id])
    end

    archive_file_count
  end

  def get_or_create_origin(name, label)
    key = [name, label]
    return @caches[:origins][key] if @caches[:origins][key]

    origin = Origin.find_or_create_by(name: name, label: label)
    @caches[:origins][key] = origin
    origin
  end

  def descend
    @node
      .xpath("c[@level!='file']")
      .map do |node|
        descendent = ArchiveObject.new(@parent_nodes + [@archive_node], node, @caches)
        files_count = descendent.process_files
        decendend_count = descendent.descend

        decendend_count + files_count
      end
      .sum
  end
end

class BundesarchivImporter
  def initialize(dir)
    @dir = dir || "data"
  end

  # Enqueue one ImportFileJob per XML file, plus a ReindexJob at lower priority.
  def enqueue_all
    xml_files = Dir.glob("*.xml", base: @dir).sort
    puts "Enqueuing #{xml_files.count} import jobs..."

    xml_files.each do |filename|
      ImportFileJob.perform_later(File.join(@dir, filename))
    end

    ReindexJob.set(priority: 10).perform_later
    puts "All jobs enqueued. Import will run in background."
  end

  # Import a single XML file. Called by ImportFileJob or directly for sync import.
  def import_file(path)
    caches = {
      nodes: ArchiveNode.all.index_by(&:source_id),
      origins: Origin.all.to_h { |o| [[o.name, o.label], o] }
    }
    doc = File.open(path) { |file| Nokogiri.XML(file) }
    doc.remove_namespaces!

    archive_description = doc.xpath("/ead/archdesc")

    if archive_description.attr("type")&.value != "inventory"
      Rails.logger.info "Skipping #{path}: not an inventory"
      return 0
    end

    archive_file_count = 0
    ActiveRecord::Base.transaction do
      archive_file_count =
        archive_description
          .xpath("//c[@level='fonds']")
          .map do |fond|
            object = ArchiveObject.new([], fond, caches)
            object.descend + object.process_files
          end
          .sum
    end

    archive_file_count
  end

  # Synchronous import of all files (for CLI / development use).
  def run(show_progress: false)
    puts "Importing data from XML files in #{@dir}..." if show_progress
    start = Time.now
    archive_file_count = 0

    xml_files = Dir.glob("*.xml", base: @dir).sort
    total = xml_files.count
    if show_progress
      progress_bar =
        ProgressBar.create(
          title: "Importing",
          total: total,
          format: "%t %p%% %a %e |%B|"
        )
    end

    xml_files.each_with_index do |filename, index|
      path = File.join(@dir, filename)

      if show_progress
        progress_bar.log "Now reading: #{filename} (#{index + 1} of #{total})"
      end

      archive_file_count += import_file(path)
      progress_bar.increment if show_progress
    end

    ArchiveFile.update_cached_all_count

    if show_progress
      puts "Finished. Imported #{archive_file_count} archive files in #{Time.now - start} seconds."
    end
  end
end
