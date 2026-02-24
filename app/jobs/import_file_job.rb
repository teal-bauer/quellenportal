class ImportFileJob < ApplicationJob
  queue_as :default

  def perform(path)
    Rails.logger.info "ImportFileJob: processing #{path}"
    importer = BundesarchivImporter.new(nil)
    repo = MeilisearchRepository.new
    origins_cache = repo.all_origins_for_cache.to_h { |o| [o['name'], o] }
    caches = {
      nodes: {},
      nodes_batch: [],
      files_batch: [],
      origins: origins_cache,
      origins_batch: [],
      progress_acc: 0.0
    }
    count = importer.import_file(path, caches: caches)
    # Flush remaining batches
    repo.upsert_files(caches[:files_batch]) if caches[:files_batch].any?
    repo.upsert_nodes(caches[:nodes_batch]) if caches[:nodes_batch].any?
    repo.upsert_origins(caches[:origins_batch]) if caches[:origins_batch].any?
    Rails.logger.info "ImportFileJob: imported #{count} archive files from #{path}"
  end
end
