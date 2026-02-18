MeiliSearch::Rails.configuration = {
  meilisearch_url: ENV.fetch('MEILISEARCH_HOST', 'http://localhost:7700'),
  meilisearch_api_key: ENV.fetch('MEILISEARCH_API_KEY', ''),
  timeout: 10,
  max_retries: 2,
  pagination_backend: :kaminari,
  per_environment: true
}
