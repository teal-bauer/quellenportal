class ImportFileJob < ApplicationJob
  queue_as :default

  def perform(path)
    Rails.logger.info "ImportFileJob: processing #{path}"
    importer = BundesarchivImporter.new(nil)
    count = importer.import_file(path)
    ArchiveFile.update_cached_all_count
    Rails.logger.info "ImportFileJob: imported #{count} archive files from #{path}"
  end
end
