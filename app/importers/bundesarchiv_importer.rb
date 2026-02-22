class ArchiveObject
  def initialize(parent_nodes, node, caches, progress_bar: nil, progress_step: 0, archive_node: nil, repository: nil)
    @parent_nodes = parent_nodes
    @node = node
    @caches = caches
    @progress_bar = progress_bar
    @progress_step = progress_step
    @repository = repository || MeilisearchRepository.new
    @archive_node = archive_node || store
  end

  def store
    node_id = clean_id(@node.attr('id'))
    if node_id.blank?
      # Fallback for archdesc which might not have an id
      unitid_text = @node.xpath('did/unitid').text
      node_id = "ROOT_#{clean_unitid(unitid_text).gsub(/[^a-zA-Z0-9]/, '_')}"
    end

    # If we already have this node in cache, return it
    return @caches[:nodes][node_id] if @caches[:nodes][node_id]

    did = @node.xpath('did')
    unitid = clean_unitid(did.xpath('unitid[@type="call number"]').text)
    unittitle = did.xpath('unittitle').text.strip

    if unitid.blank?
      # Try extracting from title: e.g. "B 112 Bundesrechnungshof" or "DL 210 Betriebe..."
      # Pattern: optional BArch, 1-4 uppercase letters, space, digits, optional suffix, then the rest
      if unittitle =~ /\A(?:BArch\s+)?([A-Z]{1,4}\s+\d+[A-Z0-9\-\.\/\s]*?)\s+(.*)\z/
        potential_id = $1.strip
        potential_title = $2.strip
        
        # Only accept if the potential title isn't just another number or empty
        if potential_title.length > 2
          unitid = potential_id
          unittitle = potential_title
        end
      end
    end

    # Extract metadata
    metadata = {
      id: node_id,
      name: unittitle,
      level: @node.attr('level') || 'fonds',
      parent_node_id: @parent_nodes.last&.dig(:id),
      parents: @parent_nodes,
      ancestor_ids: @parent_nodes.map { |p| p[:id] },
      unitid: unitid.presence,
      unitdate: did.xpath('did/unitdate').text.presence,
      name_first_letter: normalize_letter(unittitle),
      unitid_first_letter: normalize_letter(unitid),
      # Keep first_letter for backward compatibility or default
      first_letter: normalize_letter(unittitle),
      physdesc: {
        genreform: did.xpath('physdesc/genreform').text.presence,
        extent: did.xpath('physdesc/extent').map(&:text).presence || []
      },
      langmaterial: did.xpath('langmaterial').text.strip.presence,
      origination: did.xpath('origination').map { |o| { name: o.text, label: o.attr('label') } }.presence || [],
      repository: {
        corpname: did.xpath('repository/corpname').text.presence,
        address: did.xpath('repository/address/addressline').map(&:text).presence || [],
        extref: did.xpath('repository/extref').attr('href')&.value.presence
      },
      scopecontent: @node.xpath('scopecontent/p').map(&:text).join("\n\n").presence,
      relatedmaterial: @node.xpath('relatedmaterial/p').map(&:text).join("\n\n").presence,
      prefercite: @node.xpath('prefercite/p').map(&:text).join("\n\n").presence
    }

    @caches[:nodes_batch] << metadata
    if @caches[:nodes_batch].size >= 100
      @repository.upsert_nodes(@caches[:nodes_batch])
      @caches[:nodes_batch] = []
    end
    
    # Store simplified version in cache for hierarchy building
    cached_node = { id: node_id, name: unittitle, unitid: unitid }
    @caches[:nodes][node_id] = cached_node

    increment_progress

    cached_node
  end

  def process_files
    child_xpath = @node.name == 'archdesc' ? 'dsc/c' : 'c'
    file_nodes = @node.xpath("#{child_xpath}[@level='file']")
    return 0 if file_nodes.empty?

    archive_file_count = 0

    file_nodes.each_slice(1000) do |slice|
      data = slice.map do |node|
        date = UnitDate.new(node.xpath('did/unitdate').first)

        node_origins = node.xpath('did/origination').map do |origin|
          { name: origin.text, label: origin.attr('label') }
        end
        
        # Upsert origins directly
        node_origins.each do |o|
          get_or_create_origin(o[:name], o[:label])
        end

        call_number = clean_unitid(node.xpath('did/unitid[@type="call number"]').text)

        parents_cache = (@parent_nodes + [@archive_node]).map do |n|
          { name: n[:name], id: n[:id], unitid: n[:unitid] }
        end

        fonds = parents_cache.first

        {
          id: clean_id(node.attr('id')),
          archive_node_id: @archive_node[:id],
          title: node.xpath('did/unittitle').text,
          parents: parents_cache,
          ancestor_ids: parents_cache.map { |p| p[:id] },
          depth: parents_cache.size,
          fonds_id: fonds[:id],
          fonds_name: fonds[:name],
          fonds_unitid: fonds[:unitid],
          fonds_unitid_prefix: fonds[:unitid]&.split(' ')&.first,
          origin_names: node_origins.map { |o| o[:name] },
          call_number: call_number,
          source_date_text: date.text,
          source_date_start: date.start_date&.to_s,
          source_date_end: date.end_date&.to_s,
          source_date_start_uncorrected: date.start_date_uncorrected&.to_s,
          source_date_end_uncorrected: date.end_date_uncorrected&.to_s,
          source_date_start_unix: date.start_date&.to_time&.to_i,
          source_date_end_unix: date.end_date&.to_time&.to_i,
          decade: date.start_date ? (date.start_date.year / 10) * 10 : nil,
          period: date.start_date ? (date.start_date.year < 1800 ? (date.start_date.year / 100) * 100 : (date.start_date.year / 10) * 10) : nil,
          period_span: date.start_date ? (date.start_date.year < 1800 ? 100 : 10) : nil,
          link: node.xpath('otherfindaid/p/extref')[0]&.attr('href'),
          location: node.xpath('did/physloc').text,
          language_code: node.xpath('did/langmaterial/language')[0]&.attr('langcode'),
          summary: node.xpath('scopecontent[@encodinganalog="summary"]/p').text
        }
      end

      @repository.upsert_files(data)
      
      data.each { increment_progress }

      archive_file_count += data.count
    end

    archive_file_count
  end

  def get_or_create_origin(name, label)
    key = name
    return @caches[:origins][key] if @caches[:origins][key]

    # Deterministic ID from name so duplicates across files merge naturally
    origin = {
      id: Digest::SHA256.hexdigest(name)[0, 24],
      name: name,
      label: label,
      first_letter: normalize_letter(name)
    }

    @caches[:origins_batch] << origin
    if @caches[:origins_batch].size >= 100
      @repository.upsert_origins(@caches[:origins_batch])
      @caches[:origins_batch] = []
    end

    @caches[:origins][key] = origin
    origin
  end

  def descend
    child_xpath = @node.name == 'archdesc' ? 'dsc/c' : 'c'
    @node
      .xpath("#{child_xpath}[@level!='file']")
      .map do |node|
        # Avoid redundant "double header" nodes where the child is just a 
        # repetition of the parent (archdesc or structural node).
        child_title = node.xpath('did/unittitle').text
        parent_title = @archive_node[:name]
        parent_unitid = @archive_node[:unitid]

        # Normalize for comparison
        norm_child = child_title.downcase.gsub(/[^a-z0-9]/, '')
        norm_parent = parent_title.downcase.gsub(/[^a-z0-9]/, '')
        norm_unitid = parent_unitid&.downcase&.gsub(/[^a-z0-9]/, '') || ''

        is_redundant = false
        
        # 1. Exact or normalized match
        if norm_child == norm_parent
          is_redundant = true
        # 2. Child title is "UnitID ParentTitle" (normalized)
        elsif norm_unitid.present? && norm_child.include?(norm_unitid) && norm_child.include?(norm_parent)
          is_redundant = true
        # 3. Child title starts with UnitID and is very similar
        elsif norm_unitid.present? && norm_child.start_with?(norm_unitid) && norm_child.length < (norm_parent.length + norm_unitid.length + 20)
          is_redundant = true
        end

        if is_redundant
          # Adopt the child's proper ID if we are currently using a ROOT_ fallback
          child_id = clean_id(node.attr('id'))
          if @archive_node[:id].start_with?('ROOT_') && child_id.present?
            old_id = @archive_node[:id]
            
            # Transfer metadata from @archive_node to existing_node if existing_node is missing it
            @archive_node[:id] = child_id
            @repository.upsert_nodes([@archive_node])
            @repository.delete_node(old_id)

            @caches[:nodes].delete(old_id)
            @caches[:nodes][child_id] = @archive_node
          end

          # Skip this node but process its content into the EXISTING @archive_node
          phantom = ArchiveObject.new(@parent_nodes, node, @caches, 
                                     progress_bar: @progress_bar, 
                                     progress_step: @progress_step, 
                                     archive_node: @archive_node,
                                     repository: @repository)
          files_count = phantom.process_files
          decendend_count = phantom.descend
          next files_count + decendend_count
        end

        descendent = ArchiveObject.new(@parent_nodes + [@archive_node], node, @caches, 
                                      progress_bar: @progress_bar, progress_step: @progress_step,
                                      repository: @repository)
        files_count = descendent.process_files
        decendend_count = descendent.descend

        decendend_count + files_count
      end
      .sum
  end

  private

  def normalize_letter(str)
    return nil if str.blank?
    # Strip leading non-letter/non-digit characters (Unicode-aware)
    clean = str.gsub(/\A[^\p{L}\p{N}]+/, '')
    return nil if clean.empty?
    # Decompose to NFD, strip combining marks (accents), then take first char
    first = clean[0].unicode_normalize(:nfd).gsub(/\p{M}/, '')
    first = clean[0] if first.empty? # fallback for CJK etc.
    first.upcase
  end

  def clean_id(id)
    id&.sub(/\ADE-1958_/, '')
  end

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
  def initialize(dir, repository: nil)
    @dir = dir || 'data'
    @repository = repository || MeilisearchRepository.new
  end

  def enqueue_all
    xml_files = Dir.glob('*.xml', base: @dir).sort
    puts "Enqueuing #{xml_files.count} import jobs..."

    xml_files.each do |filename|
      ImportFileJob.perform_later(File.join(@dir, filename))
    end

    # No ReindexJob needed anymore as we index on the fly
    puts 'All jobs enqueued. Import will run in background.'
  end

  def import_file(path, progress_bar: nil, file_start_progress: 0, file_lines: 0)
    # Fetch origins from Meilisearch for cache
    origins_list = @repository.all_origins_for_cache
    
    caches = {
      nodes: {},
      nodes_batch: [],
      origins: origins_list.to_h { |o| [o['name'], o] },
      origins_batch: [],
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
    root_object = ArchiveObject.new([], archdesc, caches, progress_bar: progress_bar, progress_step: progress_step, repository: @repository)
    archive_file_count = root_object.process_files
    archive_file_count += root_object.descend

    # Flush remaining batches
    @repository.upsert_nodes(caches[:nodes_batch]) if caches[:nodes_batch].any?
    @repository.upsert_origins(caches[:origins_batch]) if caches[:origins_batch].any?

    # Ensure we consume the full line count budget for this file to avoid drift
    progress_bar.progress = file_start_progress + file_lines if progress_bar

    archive_file_count
  end

  def run(show_progress: false)
    puts "Configuring Meilisearch indices..." if show_progress
    @repository.configure_indices

    puts "Importing data from XML files in #{@dir}..." if show_progress
    start = Time.now
    archive_file_count = 0

    xml_files = Dir.glob('*.xml', base: @dir).sort
    
    file_line_counts = {}
    total_lines = 0

    if show_progress
      # Use xargs to count lines for all files in one or a few goes
      begin
        paths = xml_files.map { |f| File.join(@dir, f) }
        
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

    # Clear Rails caches
    Rails.cache.delete('origins/with_file_counts')
    Rails.cache.delete('archive_files/decade_counts')
    Rails.cache.delete('browse/tab_counts')

    return unless show_progress

    puts "Finished. Imported #{archive_file_count} archive files in #{Time.now - start} seconds."
  end
end
