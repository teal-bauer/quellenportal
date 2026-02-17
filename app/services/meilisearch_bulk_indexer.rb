require "net/http"
require "json"

class MeilisearchBulkIndexer
  BATCH_SIZE = 5_000

  def initialize(verbose: false)
    @verbose = verbose
    @meili_url = ENV.fetch("MEILISEARCH_HOST", "http://localhost:7700")
    @meili_key = ENV.fetch("MEILISEARCH_API_KEY", "")
    @index_name = "ArchiveFile_#{Rails.env}"

    uri = URI.parse(@meili_url)
    @http = Net::HTTP.new(uri.host, uri.port)
    @http.use_ssl = uri.scheme == "https"
    @http.read_timeout = 120
  end

  def call
    delete_index
    create_index
    configure_settings
    bulk_load_documents
    Rails.cache.delete("browse/tab_counts")
    Rails.cache.delete("browse/fonds_letters")
    Rails.cache.delete("browse/origin_letters")
    Rails.cache.delete("archive_files/decade_counts")
    Rails.cache.delete("origins/with_file_counts")
  end

  private

  def delete_index
    log "Deleting index #{@index_name}..."
    meili_request(:delete, "/indexes/#{@index_name}")
    sleep 1
  end

  def create_index
    log "Creating index #{@index_name}..."
    meili_request(:post, "/indexes", { uid: @index_name, primaryKey: "id" })
    sleep 1
  end

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

  def configure_settings
    log "Configuring index settings..."
    meili_request(:patch, "/indexes/#{@index_name}/settings", {
      searchableAttributes: %w[title summary call_number parent_names origin_names],
      filterableAttributes: %w[fonds_id fonds_name decade archive_node_id source_date_start_unix],
      sortableAttributes: %w[call_number],
      stopWords: GERMAN_STOP_WORDS,
      typoTolerance: {
        enabled: true,
        minWordSizeForTypos: { oneTypo: 4, twoTypos: 8 }
      },
      faceting: { maxValuesPerFacet: 100 },
      pagination: { maxTotalHits: 100_000 }
    })
  end

  def bulk_load_documents
    pool = ActiveRecord::Base.connection_pool

    total, max_id = pool.with_connection do |conn|
      [conn.select_value("SELECT COUNT(*) FROM archive_files"),
       conn.select_value("SELECT MAX(id) FROM archive_files")]
    end

    log "Indexing #{total} documents in batches of #{BATCH_SIZE}..."
    start = Time.now
    indexed = 0

    return unless max_id

    (0..max_id).step(BATCH_SIZE) do |offset_id|
      rows = pool.with_connection do |conn|
        conn.select_all(<<~SQL).to_a
          SELECT
            af.id,
            af.title,
            af.summary,
            af.call_number,
            af.archive_node_id,
            CAST(json_extract(af.parents, '$[0].id') AS INTEGER) AS fonds_id,
            json_extract(af.parents, '$[0].name') AS fonds_name,
            CASE WHEN af.source_date_start IS NOT NULL
              THEN (CAST(strftime('%Y', af.source_date_start) AS INTEGER) / 10) * 10
              ELSE NULL END AS decade,
            CASE WHEN af.source_date_start IS NOT NULL
              THEN CAST(strftime('%s', af.source_date_start) AS INTEGER)
              ELSE NULL END AS source_date_start_unix,
            (SELECT GROUP_CONCAT(json_extract(value, '$.name'), ' ')
             FROM json_each(af.parents)) AS parent_names,
            COALESCE((SELECT GROUP_CONCAT(o.name, ' ')
             FROM originations ori JOIN origins o ON ori.origin_id = o.id
             WHERE ori.archive_file_id = af.id), '') AS origin_names
          FROM archive_files af
          WHERE af.id > #{offset_id} AND af.id <= #{offset_id + BATCH_SIZE}
        SQL
      end

      next if rows.empty?

      meili_request(:post, "/indexes/#{@index_name}/documents", rows)
      indexed += rows.size
      log_progress(indexed, total) if @verbose
    end

    elapsed = Time.now - start
    rate = elapsed > 0 ? (indexed / elapsed).round(0) : 0
    log "Indexed #{indexed} documents in #{elapsed.round(1)}s (#{rate} docs/s)"
  end

  def meili_request(method, path, body = nil, retries: 5)
    req = case method
    when :get then Net::HTTP::Get.new(path)
    when :post then Net::HTTP::Post.new(path)
    when :patch then Net::HTTP::Patch.new(path)
    when :delete then Net::HTTP::Delete.new(path)
    end

    req["Authorization"] = "Bearer #{@meili_key}"
    if body
      req["Content-Type"] = "application/json"
      req.body = body.to_json
    end

    attempts = 0
    begin
      attempts += 1
      reconnect_http! if @http.nil?
      @http.request(req)
    rescue Socket::ResolutionError, Errno::ECONNREFUSED, Errno::ECONNRESET,
           Net::OpenTimeout, Net::ReadTimeout, EOFError => e
      raise if attempts > retries
      wait = 2**attempts
      log "  Connection error (#{e.class}), retry #{attempts}/#{retries} in #{wait}s..."
      sleep wait
      @http = nil
      retry
    end
  end

  def reconnect_http!
    uri = URI.parse(@meili_url)
    @http = Net::HTTP.new(uri.host, uri.port)
    @http.use_ssl = uri.scheme == "https"
    @http.read_timeout = 120
  end

  def log(msg)
    if @verbose
      puts msg
    else
      Rails.logger.info "MeilisearchBulkIndexer: #{msg}"
    end
  end

  def log_progress(indexed, total)
    pct = (indexed.to_f / total * 100).round(1)
    print "\r  #{indexed}/#{total} (#{pct}%)"
  end
end
