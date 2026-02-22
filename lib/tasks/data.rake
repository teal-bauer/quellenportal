namespace :data do
  SOURCE_URL = 'https://open-data.bundesarchiv.de/apex-ead/'

  desc 'Download XML files from Bundesarchiv Open Data'
  task :download, [:dir] => [:environment] do |_task, args|
    require 'open-uri'
    require 'nokogiri'

    dir = args[:dir] || Rails.root.join('data').to_s
    FileUtils.mkdir_p(dir)

    puts "Fetching file listing from #{SOURCE_URL}..."
    doc = Nokogiri::HTML(URI.parse(SOURCE_URL).open)
    files = doc.css("a[href$='.xml']").map { |a| a['href'] }
    puts "Found #{files.size} XML files"

    files.each_with_index do |filename, i|
      path = File.join(dir, filename)
      if File.exist?(path)
        print "\r[#{i + 1}/#{files.size}] Skipping #{filename} (exists)"
        next
      end

      print "\r[#{i + 1}/#{files.size}] Downloading #{filename}...".ljust(80)
      URI.parse("#{SOURCE_URL}#{filename}").open do |remote|
        File.open(path, 'wb') { |f| f.write(remote.read) }
      end
    end
    puts "\nDone."
  end

  desc 'Import data from XML files (background via async queue)'
  task :import, [:dir] => [:environment] do |_task, args|
    BundesarchivImporter.new(args[:dir]).enqueue_all
  end

  desc 'Import data from XML files (synchronous)'
  task :import_sync, [:dir] => [:environment] do |_task, args|
    BundesarchivImporter.new(args[:dir]).run(show_progress: true)
  end

  desc 'Configure Meilisearch indices (search/sort/filter settings)'
  task configure_indices: :environment do
    MeilisearchRepository.new.configure_indices
    puts "Indices configured."
  end

  desc 'Delete and recreate all Meilisearch indices with correct primary keys'
  task recreate_indices: :environment do
    MeilisearchRepository.new.recreate_indices
    puts "Indices recreated and configured."
  end

  desc 'Rebuild origins index from XML data (dedup + normalize, blue-green swap)'
  task :rebuild_origins, [:dir] => [:environment] do |_task, args|
    dir = args[:dir] || 'data'
    repo = MeilisearchRepository.new

    live_index = "Origin_#{Rails.env}"
    shadow_index = "Origin_#{Rails.env}_new"

    # Prepare shadow index (delete if leftover from previous failed run)
    puts "Preparing shadow index #{shadow_index}..."
    repo.delete_index(shadow_index)
    sleep 2
    repo.post("/indexes", { uid: shadow_index, primaryKey: 'id' })
    repo.configure_origin_index(shadow_index)

    # Scan all XML files for origination elements
    origins = {}
    xml_files = Dir.glob('*.xml', base: dir).sort

    xml_files.each_with_index do |filename, i|
      print "\r[#{i + 1}/#{xml_files.size}] Scanning #{filename}...".ljust(80)
      doc = File.open(File.join(dir, filename)) { |f| Nokogiri.XML(f) }
      doc.remove_namespaces!

      doc.xpath('//origination').each do |orig|
        name = orig.text.strip
        next if name.blank?

        unless origins.key?(name)
          first = name.gsub(/\A[^\p{L}\p{N}]+/, '')
          letter = first[0]&.unicode_normalize(:nfd)&.gsub(/\p{M}/, '')&.upcase
          letter = first[0]&.upcase if letter.blank?

          origins[name] = {
            id: Digest::SHA256.hexdigest(name)[0, 24],
            name: name,
            label: orig.attr('label'),
            first_letter: letter
          }
        end
      end
    end

    puts "\nFound #{origins.size} unique origins. Upserting to shadow index..."
    origins.values.each_slice(1000) do |batch|
      repo.post("/indexes/#{shadow_index}/documents", batch)
    end

    # Wait for Meilisearch to finish indexing the shadow
    puts "Waiting for shadow index to finish indexing..."
    loop do
      stats = repo.get("/indexes/#{shadow_index}/stats")
      break unless stats['isIndexing']
      sleep 2
    end

    # Atomic swap: live <-> shadow
    puts "Swapping #{live_index} <-> #{shadow_index}..."
    resp = repo.swap_indexes([{ indexes: [live_index, shadow_index] }])
    task_uid = resp['taskUid']
    repo.wait_for_task(task_uid)

    # Clean up the old index (now at the shadow name)
    puts "Cleaning up old index..."
    repo.delete_index(shadow_index)

    puts "Done. #{origins.size} unique origins live in #{live_index}."
  end
end
