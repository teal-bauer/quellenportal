class ReindexJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "ReindexJob: rebuilding Meilisearch index"
    MeilisearchBulkIndexer.new.call
    Rails.logger.info "ReindexJob: reindex complete"
  end
end
