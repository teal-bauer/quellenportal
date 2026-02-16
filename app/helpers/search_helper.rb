module SearchHelper
  def query_cache_key(query)
    query ||= ""
    Digest::SHA512.hexdigest query + Rails.application.config.cache_key_salt
  end

  def facet_url(add: {}, remove: [])
    base = { q: @query, node_id: @node_id, from: @date_from, to: @date_to }
    remove.each { |k| base.delete(k) }
    base.merge!(add)
    root_path(base.compact)
  end
end
