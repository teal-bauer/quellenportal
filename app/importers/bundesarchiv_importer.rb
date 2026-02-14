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

        # Collect origin info without DB hits
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

      # Build source_id -> id mapping from results
      id_map = results.to_h { |r| [r["source_id"], r["id"]] }

      # Batch collect originations
      data.zip(origin_data).each do |file_data, origins|
        file_id = id_map[file_data[:source_id]]
        origins.each do |origin_attrs|
          origin = get_or_create_origin(origin_attrs[:name], origin_attrs[:label])
          originations_to_insert << { archive_file_id: file_id, origin_id: origin.id }
        end
      end

      archive_file_count += data.count
    end

    # Batch insert originations
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
    @caches = {
      origins: {},
      nodes: {}
    }
  end

  def run(show_progress: false)
    puts "Importing data from XML files in #{@dir}..." if show_progress
    start = Time.now
    archive_file_count = 0

    # Disable fsync for faster bulk import (data loss risk on crash)
    ActiveRecord::Base.connection.execute("PRAGMA synchronous=OFF")

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
      doc = File.open(path) { |file| Nokogiri.XML(file) }

      # I can't figure out how these work in the documents I have, so out they go:
      doc.remove_namespaces!

      if show_progress
        progress_bar.log "Now reading: #{filename} (#{index + 1} of #{total})"
      end

      archive_description = doc.xpath("/ead/archdesc")

      if (archive_description.attr("type").value != "inventory")
        if show_progress
          puts "Skipping #{filename} because it's not an inventory"
        end
        next
      end

      # Wrap each file in a transaction for faster commits
      ActiveRecord::Base.transaction do
        archive_file_count +=
          archive_description
            .xpath("//c[@level='fonds']")
            .map do |fond|
              object = ArchiveObject.new([], fond, @caches)
              object.descend + object.process_files
            end
            .sum
      end

      progress_bar.increment if show_progress
    end

    # Restore safe sync mode
    ActiveRecord::Base.connection.execute("PRAGMA synchronous=NORMAL")

    ArchiveFile.update_cached_all_count

    if show_progress
      puts "Finished. Imported #{archive_file_count} archive files in #{Time.now - start} seconds."
    end
  end
end
