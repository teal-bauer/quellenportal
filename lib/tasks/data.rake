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
end
