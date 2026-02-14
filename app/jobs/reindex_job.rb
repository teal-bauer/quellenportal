class ReindexJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "ReindexJob: rebuilding FTS5 trigram index"
    ArchiveFile.reindex
    Rails.logger.info "ReindexJob: reindex complete"
  end
end
