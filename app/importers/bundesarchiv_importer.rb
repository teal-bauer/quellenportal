class ArchiveObject
  def initialize(parent_nodes, node, caches, progress_bar: nil, progress_step: 0)
    @parent_nodes = parent_nodes
    @node = node
    @caches = caches
    @progress_bar = progress_bar
    @progress_step = progress_step
    @archive_node = store
  end

  def store
    source_id = @node.attr('id')
    if source_id.blank?
      # Fallback for archdesc which might not have an id
      unitid_text = @node.xpath('did/unitid').text
      source_id = "ROOT_#{clean_unitid(unitid_text).gsub(/[^a-zA-Z0-9]/, '_')}"
    end

    return @caches[:nodes][source_id] if @caches[:nodes][source_id]

    node = ArchiveNode.find_or_initialize_by(source_id: source_id)

    did = @node.xpath('did')
    unitid = clean_unitid(did.xpath('unitid[@type="call number"]').text)
    unittitle = did.xpath('unittitle').text

    # Extract metadata
    metadata = {
      name: unittitle,
      level: @node.attr('level') || 'fonds',
      parent_node: @parent_nodes.last,
      unitid: unitid,
      unitdate: did.xpath('unitdate').text,
      physdesc: {
        genreform: did.xpath('physdesc/genreform').text,
        extent: did.xpath('physdesc/extent').map(&:text)
      },
      langmaterial: did.xpath('langmaterial').text.strip,
      origination: did.xpath('origination').map { |o| { name: o.text, label: o.attr('label') } },
      repository: {
        corpname: did.xpath('repository/corpname').text,
        address: did.xpath('repository/address/addressline').map(&:text),
        extref: did.xpath('repository/extref').attr('href')&.value
      },
      scopecontent: @node.xpath('scopecontent/p').map(&:text).join("\n\n"),
      relatedmaterial: @node.xpath('relatedmaterial/p').map(&:text).join("\n\n"),
      prefercite: @node.xpath('prefercite/p').map(&:text).join("\n\n")
    }

    node.assign_attributes(metadata)
    node.save! if node.new_record? || node.changed?
    @caches[:nodes][source_id] = node

    increment_progress

    node
  end

  def process_files
    child_xpath = @node.name == 'archdesc' ? 'dsc/c' : 'c'
    file_nodes = @node.xpath("#{child_xpath}[@level='file']")
    return 0 if file_nodes.empty?

    archive_file_count = 0
    originations_to_insert = []

    file_nodes.each_slice(1000) do |slice|
      origin_data = []
      data = slice.map do |node|
        date = UnitDate.new(node.xpath('did/unitdate').first)

        node_origins = node.xpath('did/origination').map do |origin|
          { name: origin.text, label: origin.attr('label') }
        end
        origin_data << node_origins

        call_number = clean_unitid(node.xpath('did/unitid[@type="call number"]').text)

        parents_cache = (@parent_nodes + [@archive_node]).map do |n|
          { name: n.name, id: n.id, unitid: n.unitid }
        end

        {
          archive_node_id: @archive_node.id,
          title: node.xpath('did/unittitle').text,
          parents: parents_cache,
          call_number: call_number,
          source_date_text: date.text,
          source_date_start: date.start_date,
          source_date_end: date.end_date,
          source_date_start_uncorrected: date.start_date_uncorrected,
          source_date_end_uncorrected: date.end_date_uncorrected,
          source_id: node.attr('id'),
          link: node.xpath('otherfindaid/p/extref')[0]&.attr('href'),
          location: node.xpath('did/physloc').text,
          language_code: node.xpath('did/langmaterial/language')[0]&.attr('langcode'),
          summary: node.xpath('scopecontent[@encodinganalog="summary"]/p').text
        }
      end

      results = ArchiveFile.upsert_all(data, unique_by: :source_id, returning: %i[id source_id])
      id_map = results.to_h { |r| [r['source_id'], r['id']] }

      data.zip(origin_data).each do |file_data, origins|
        file_id = id_map[file_data[:source_id]]
        origins.each do |origin_attrs|
          origin = get_or_create_origin(origin_attrs[:name], origin_attrs[:label])
          originations_to_insert << { archive_file_id: file_id, origin_id: origin.id }
        end
        increment_progress
      end

      archive_file_count += data.count
    end

    if originations_to_insert.any?
      Origination.insert_all(originations_to_insert, unique_by: %i[archive_file_id origin_id])
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
    child_xpath = @node.name == 'archdesc' ? 'dsc/c' : 'c'
    @node
      .xpath("#{child_xpath}[@level!='file']")
      .map do |node|
        descendent = ArchiveObject.new(@parent_nodes + [@archive_node], node, @caches, progress_bar: @progress_bar, progress_step: @progress_step)
        files_count = descendent.process_files
        decendend_count = descendent.descend

        decendend_count + files_count
      end
      .sum
  end

  private

  def clean_unitid(unitid)
    unitid&.sub(/\ABArch /, '')&.strip
  end

  def increment_progress(amount = nil)
    return unless @progress_bar
    step = amount || @progress_step
    return if step <= 0
    
    @caches[:progress_acc] ||= 0.0
    @caches[:progress_acc] += step
    
    if @caches[:progress_acc] >= 1.0
      whole_steps = @caches[:progress_acc].floor
      @progress_bar.progress = [@progress_bar.progress + whole_steps, @progress_bar.total].min
      @caches[:progress_acc] -= whole_steps
    end
  end
end

class BundesarchivImporter
  def initialize(dir)
    @dir = dir || 'data'
  end

  def enqueue_all
    xml_files = Dir.glob('*.xml', base: @dir).sort
    puts "Enqueuing #{xml_files.count} import jobs..."

    xml_files.each do |filename|
      ImportFileJob.perform_later(File.join(@dir, filename))
    end

    ReindexJob.set(priority: 10).perform_later
    puts 'All jobs enqueued. Import will run in background.'
  end

  def import_file(path, progress_bar: nil, file_start_progress: 0, file_lines: 0)
    caches = {
      nodes: {},
      origins: Origin.all.to_h { |o| [[o.name, o.label], o] },
      progress_acc: 0.0
    }

    doc = File.open(path) { |file| Nokogiri.XML(file) }
    doc.remove_namespaces!

    # Parsing is roughly 5% of the work. Add it to accumulator.
    if progress_bar
      caches[:progress_acc] += (file_lines * 0.05)
      if caches[:progress_acc] >= 1.0
        whole_steps = caches[:progress_acc].floor
        progress_bar.progress = [progress_bar.progress + whole_steps, progress_bar.total].min
        caches[:progress_acc] -= whole_steps
      end
    end

    archdesc = doc.at_xpath('/ead/archdesc')

    if archdesc.nil? || archdesc['type'] != 'inventory'
      Rails.logger.info "Skipping #{path}: not an inventory"
      progress_bar.progress = file_start_progress + file_lines if progress_bar
      return 0
    end

    # Count all 'c' elements to distribute the remaining 95% of file_lines
    c_count = doc.xpath('//c').count
    progress_step = c_count > 0 ? (file_lines * 0.95) / c_count : 0

    archive_file_count = 0
    ActiveRecord::Base.transaction do
      root_object = ArchiveObject.new([], archdesc, caches, progress_bar: progress_bar, progress_step: progress_step)
      archive_file_count = root_object.process_files
      archive_file_count += root_object.descend
    end

    archive_file_count
  end

  def run(show_progress: false)
    puts "Importing data from XML files in #{@dir}..." if show_progress
    start = Time.now
    archive_file_count = 0

    unless ActiveRecord::Base.connection.open_transactions > 0
      conn = ActiveRecord::Base.connection
      conn.execute('PRAGMA synchronous = OFF')
      conn.execute('PRAGMA journal_mode = MEMORY')
      conn.execute('PRAGMA cache_size = -512000') # 512MB
    end

    xml_files = Dir.glob('*.xml', base: @dir).sort
    
    file_line_counts = {}
    total_lines = 0

    if show_progress
      # Use xargs to count lines for all files in one or a few goes
      # This is much faster than spawning a shell per file
      begin
        paths = xml_files.map { |f| File.join(@dir, f) }
        
        # Capture3 to pass filenames safely to xargs
        require 'open3'
        stdout, _stderr, status = Open3.capture3("xargs wc -l", stdin_data: paths.join("\n"))
        
        if status.success?
          stdout.each_line do |line|
            parts = line.strip.split(/\s+/)
            next if parts.size < 2
            
            count = parts[0].to_i
            path = parts[1..].join(' ')
            
            next if path == 'total' || path.empty?
            
            filename = File.basename(path)
            file_line_counts[filename] = count
            total_lines += count
          end
        else
          # Fallback
          xml_files.each do |filename|
            lines = `wc -l < "#{File.join(@dir, filename)}"`.to_i
            file_line_counts[filename] = lines
            total_lines += lines
          end
        end
      rescue => e
        Rails.logger.error "Bulk line count failed, falling back: #{e.message}"
        xml_files.each do |filename|
          lines = `wc -l < "#{File.join(@dir, filename)}"`.to_i
          file_line_counts[filename] = lines
          total_lines += lines
        end
      end

      progress_bar =
        ProgressBar.create(
          title: 'Importing',
          total: total_lines,
          format: '%t %p%% %a %e |%B|',
          autofinish: false
        )
    end

    current_start_progress = 0
    xml_files.each_with_index do |filename, index|
      path = File.join(@dir, filename)
      lines = file_line_counts[filename] || 0
      
      progress_bar.log "Now reading: #{filename} (#{index + 1} of #{xml_files.count})" if show_progress
      
      archive_file_count += import_file(path, progress_bar: progress_bar, file_start_progress: current_start_progress, file_lines: lines)
      
      current_start_progress += lines
      # Ensure bar is perfectly aligned with file boundaries
      progress_bar.progress = [current_start_progress, total_lines].min if progress_bar
    end

    progress_bar.finish if show_progress

    ArchiveFile.update_cached_all_count
    Rails.cache.delete('origins/with_file_counts')
    Rails.cache.delete('archive_files/decade_counts')
    Rails.cache.delete('browse/tab_counts')

    return unless show_progress

    puts "Finished. Imported #{archive_file_count} archive files in #{Time.now - start} seconds."
  end
end
