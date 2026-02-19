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
    @http.read_timeout = 60
  end

  # -- Configuration --

  GERMAN_STOP_WORDS = %w[
    aber alle allem allen aller allerdings alles also am an ander andere anderem
    anderen anderer anderes anderm andern anderr anders auch auf aus bei beim
    bin bis bist da damit dann das dass dasselbe dazu dein deine deinem deinen
    deiner dem den denn der des desselben dessen die dies diese dieselbe
    dieselben diesem diesen dieser dieses doch dort du durch ein eine einem
    einen einer einige einigem einigen einiger einiges einmal er es etwas euch
    euer eure eurem euren eurer für gegen gewesen hab habe haben hat hatte
    hätte hier hin hinter ich ihm ihn ihnen ihr ihre ihrem ihren ihrer im in
    indem ins ist jede jedem jeden jeder jedes jedoch jenem jenen jener jenes
    jetzt kann kein keine keinem keinen keiner könnte machen man manche manchem
    manchen mancher manches mein meine meinem meinen meiner mit muss musste
    nach nicht nichts noch nun nur ob oder ohne sehr sein seine seinem seinen
    seiner seit sich sie sind so solche solchem solchen solcher soll sollte
    sondern sonst über um und uns unser unsere unserem unseren unserer unter
    viel vom von vor während war warum was weil welch welche welchem welchen
    welcher wenn wer werde werden wie wieder will wir wird wirst wo wollen
    wollt würde würden zu zum zur zwar zwischen
  ].freeze

  def configure_indices
    # Ensure indices exist with correct primary key
    [@file_index, @node_index, @origin_index].each do |idx|
      begin
        post("/indexes", { uid: idx, primaryKey: 'id' })
      rescue
        # Ignore if index already exists
      end
    end

    # ArchiveFile settings
    patch("/indexes/#{@file_index}/settings", {
      searchableAttributes: %w[title summary call_number parent_names origin_names],
      filterableAttributes: %w[fonds_id fonds_name decade period period_span archive_node_id source_date_start_unix ancestor_ids depth],
      sortableAttributes: %w[call_number],
      stopWords: GERMAN_STOP_WORDS,
      typoTolerance: {
        enabled: true,
        minWordSizeForTypos: { oneTypo: 4, twoTypos: 8 }
      },
      faceting: { maxValuesPerFacet: 100 },
      pagination: { maxTotalHits: 100_000 }
    })

    # ArchiveNode settings
    patch("/indexes/#{@node_index}/settings", {
      searchableAttributes: %w[name unitid scopecontent],
      filterableAttributes: %w[parent_node_id level first_letter name_first_letter unitid_first_letter],
      sortableAttributes: %w[name unitid],
      pagination: { maxTotalHits: 100_000 }
    })

    # Origin settings
    patch("/indexes/#{@origin_index}/settings", {
      searchableAttributes: %w[name label],
      filterableAttributes: %w[first_letter],
      sortableAttributes: %w[name file_count],
      pagination: { maxTotalHits: 100_000 }
    })
  end

  def patch(path, body)
    req = Net::HTTP::Patch.new(path)
    req['Authorization'] = "Bearer #{@meili_key}"
    req['Content-Type'] = 'application/json'
    req.body = body.to_json
    perform(req)
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

  def root_nodes(page: 1, per_page: 50, letter: nil, sort_by: 'name')
    filter = ["level = 'fonds'"]
    
    sort_field = sort_by == 'unitid' ? 'unitid' : 'name'
    letter_field = sort_by == 'unitid' ? 'unitid_first_letter' : 'name_first_letter'
    
    filter << "#{letter_field} = '#{letter}'" if letter.present?
    
    options = {
      filter: filter.join(' AND '),
      sort: ["#{sort_field}:asc"],
      hitsPerPage: per_page,
      page: page
    }
    
    search_nodes("", options)
  end

  def fonds_letters(sort_by: 'name')
    letter_field = sort_by == 'unitid' ? 'unitid_first_letter' : 'name_first_letter'
    
    options = {
      filter: "level = 'fonds'",
      facets: [letter_field],
      hitsPerPage: 0
    }
    resp = search_nodes("", options)
    resp['facetDistribution']&.dig(letter_field)&.keys&.sort || []
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
      delete("/indexes/#{idx}")
    end
  end

  def delete_index(name)
    delete("/indexes/#{name}")
  rescue
    nil
  end

  def recreate_indices
    [@file_index, @node_index, @origin_index].each do |idx|
      delete_index(idx)
      # Wait a bit for deletion to process
      sleep 1 
      post("/indexes", { uid: idx, primaryKey: 'id' })
    end
    configure_indices
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
