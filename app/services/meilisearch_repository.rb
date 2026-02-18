require 'net/http'
require 'json'

class MeilisearchRepository
  def initialize
    @meili_url = ENV.fetch('MEILISEARCH_HOST', 'http://localhost:7700')
    @meili_key = ENV.fetch('MEILISEARCH_API_KEY', '')
    @file_index = "ArchiveFile_#{Rails.env}"
    @node_index = "ArchiveNode_#{Rails.env}"
    @origin_index = "Origin_#{Rails.env}"
    
    uri = URI.parse(@meili_url)
    @http = Net::HTTP.new(uri.host, uri.port)
    @http.use_ssl = uri.scheme == 'https'
    @http.read_timeout = 5
  end

  # -- Generic Search --
  
  def search_files(query, options = {})
    post("/indexes/#{@file_index}/search", { q: query }.merge(options))
  end

  def search_nodes(query, options = {})
    post("/indexes/#{@node_index}/search", { q: query }.merge(options))
  end
  
  def search_origins(query, options = {})
    post("/indexes/#{@origin_index}/search", { q: query }.merge(options))
  end

  # -- Specific Accessors --

  def get_file(id)
    return nil if id.blank?
    get("/indexes/#{@file_index}/documents/#{id}")
  rescue
    nil
  end

  def get_node(id)
    return nil if id.blank?
    get("/indexes/#{@node_index}/documents/#{id}")
  rescue
    nil
  end
  
  def get_origin(id)
    return nil if id.blank?
    get("/indexes/#{@origin_index}/documents/#{id}")
  rescue
    nil
  end

  def root_nodes(page: 1, per_page: 50, letter: nil)
    filter = ["level = 'fonds'"]
    filter << "first_letter = '#{letter}'" if letter.present?
    
    options = {
      filter: filter.join(' AND '),
      sort: ['name:asc'],
      hitsPerPage: per_page,
      page: page
    }
    
    search_nodes("", options)
  end

  def fonds_letters
    # Get all available first letters via faceting
    options = {
      filter: "level = 'fonds'",
      facets: ['first_letter'],
      hitsPerPage: 0
    }
    resp = search_nodes("", options)
    resp['facetDistribution']&.dig('first_letter')&.keys&.sort || []
  rescue
    []
  end

  def all_origins(page: 1, per_page: 50, letter: nil)
    filter = []
    filter << "first_letter = '#{letter}'" if letter.present?

    options = {
      filter: filter.join(' AND '),
      sort: ['name:asc'],
      hitsPerPage: per_page,
      page: page
    }
    search_origins("", options)
  end
  
  def origin_letters
    options = {
      facets: ['first_letter'],
      hitsPerPage: 0
    }
    resp = search_origins("", options)
    resp['facetDistribution']&.dig('first_letter')&.keys&.sort || []
  rescue
    []
  end

  # -- Write Operations --

  def upsert_files(documents)
    return if documents.empty?
    post("/indexes/#{@file_index}/documents", documents)
  end

  def upsert_nodes(documents)
    return if documents.empty?
    post("/indexes/#{@node_index}/documents", documents)
  end

  def upsert_origins(documents)
    return if documents.empty?
    post("/indexes/#{@origin_index}/documents", documents)
  end

  def stats
    # Quick stats from Meilisearch
    {
      files: get_stats(@file_index),
      nodes: get_stats(@node_index),
      origins: get_stats(@origin_index)
    }
  end

  def all_origins_for_cache
    # Fetch all origins without pagination for the importer cache
    # Meilisearch default limit is 20, so we need a large number
    resp = get("/indexes/#{@origin_index}/documents?limit=10000")
    resp['results'] || []
  rescue
    []
  end

  def delete_all
    [@file_index, @node_index, @origin_index].each do |idx|
      delete("/indexes/#{idx}/documents")
    end
  end

  private

  def delete(path)
    req = Net::HTTP::Delete.new(path)
    req['Authorization'] = "Bearer #{@meili_key}"
    perform(req)
  end

  def get_stats(index)
    resp = get("/indexes/#{index}/stats")
    resp['numberOfDocuments'] || 0
  rescue
    0
  end

  def get(path)
    req = Net::HTTP::Get.new(path)
    req['Authorization'] = "Bearer #{@meili_key}"
    perform(req)
  end

  def post(path, body)
    req = Net::HTTP::Post.new(path)
    req['Authorization'] = "Bearer #{@meili_key}"
    req['Content-Type'] = 'application/json'
    req.body = body.to_json
    perform(req)
  end

  def perform(req)
    # Reconnect if needed
    uri = URI.parse(@meili_url)
    if @http.nil? || !@http.started?
      @http = Net::HTTP.new(uri.host, uri.port)
      @http.use_ssl = uri.scheme == 'https'
    end

    res = @http.request(req)
    if res.is_a?(Net::HTTPSuccess)
      JSON.parse(res.body)
    else
      # Simple error handling
      Rails.logger.error("Meilisearch Error: #{res.code} #{res.body}")
      raise "Meilisearch request failed: #{res.code}"
    end
  end
end
