class ArchiveObject
  def initialize(parent_nodes, node)
    @parent_nodes = parent_nodes
    @node = node
    @archive_node = store
  end

  def store
    ArchiveNode.find_or_create_by(
      name: @node.xpath("did/unittitle").text,
      source_id: @node.attr("id"),
      level: @node.attr("level"),
      parent_node: @parent_nodes.last
    )
  end

  def process_files
    archive_file_count = 0

    @node
      .xpath("c[@level='file']")
      .each_slice(1000) do |slice|
        data =
          slice.map do |node|
            date = UnitDate.new(node.xpath("did/unitdate").first)
            origins =
              node
                .xpath("did/origination")
                .map do |origin|
                  Origin.find_or_create_by(
                    name: origin.text,
                    label: origin.attr("label")
                  )
                end
            call_number =
              node
                .xpath('did/unitid[@type="call number"]')
                .text
                .sub(/\ABArch /, "")

            parents_cache =
              (@parent_nodes + [@archive_node]).map do |n|
                { name: n.name, id: n.id }
              end
            {
              origins: origins,
              archive_file: {
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
                language_code:
                  node.xpath("did/langmaterial/language")[0]&.attr("langcode"),
                summary:
                  node.xpath('scopecontent[@encodinganalog="summary"]/p').text
              }
            }
          end
        archive_files =
          ArchiveFile.upsert_all(
            data.map { |d| d[:archive_file] },
            unique_by: :source_id,
            returning: :id
          )
        data
          .zip(archive_files)
          .each do |d, r|
            d[:origins].each do |origin|
              origin.archive_files << ArchiveFile.find(r["id"])
            end
          end

        archive_file_count += data.count
      end

    archive_file_count
  end

  def descend
    @node
      .xpath("c[@level!='file']")
      .map do |node|
        descendent = ArchiveObject.new(@parent_nodes + [@archive_node], node)
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

      archive_file_count +=
        archive_description
          .xpath("//c[@level='fonds']")
          .map do |fond|
            object = ArchiveObject.new([], fond)
            object.descend + object.process_files
          end
          .sum

      progress_bar.increment if show_progress
    end

    ArchiveFile.update_cached_all_count

    if show_progress
      puts "Finished. Imported #{archive_file_count} archive files in #{Time.now - start} seconds."
    end
  end
end
