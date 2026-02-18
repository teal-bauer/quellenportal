class SearchController < ApplicationController
  helper SearchHelper

  def index
    @total = ArchiveFile.cached_all_count
    @query = params[:q]
    @node_id = params[:node_id]
    @archive_node = ArchiveNode.find_by(id: @node_id) if @node_id.present?
    @unitid = params[:unitid]
    @unitid_prefix = params[:unitid_prefix]
    @date_from =
      params[:from].present? ? Date.parse(params[:from]) : nil
    @date_to =
      params[:to].present? ? Date.parse(params[:to]) : nil

    if @query.present?
      begin
        filter = build_meilisearch_filter
        sort = params[:sort] == 'call_number' ? ['call_number:asc'] : nil

        search_opts = {
          filter: filter,
          facets: %w[fonds_name fonds_unitid fonds_unitid_prefix decade],
          sort: sort,
          hits_per_page: 100,
          page: (params[:page] || 1).to_i
        }.compact

        @results = ArchiveFile.search(@query, **search_opts)

        raw = @results.raw_answer
        @facets = raw['facetDistribution']
        @total_count = raw['totalHits'] || raw['estimatedTotalHits'] || 0

        # Map fonds identifiers → fonds_id for facet links
        @fonds_id_map = {}
        if @facets
          fonds_names = @facets['fonds_name']&.keys || []
          fonds_unitids = @facets['fonds_unitid']&.keys || []
          nodes = ArchiveNode.where(parent_node_id: nil)
                             .where('name IN (?) OR unitid IN (?)', fonds_names, fonds_unitids)
          nodes.each do |node|
            @fonds_id_map[node.name] = node.id
            @fonds_id_map[node.unitid] = node.id if node.unitid.present?
          end
        end
      rescue MeiliSearch::ApiError, Socket::ResolutionError,
             Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout => e
        Rails.logger.error "Meilisearch error: #{e.class}: #{e.message}"
        @search_error = true
        @results = ArchiveFile.none.page(1)
        @total_count = 0
      end
    else
      @tab = params[:tab]
      @browse_counts = browse_counts
      load_browse_data
    end
  end

  private

  def build_meilisearch_filter
    parts = []

    if @node_id.present?
      node = ArchiveNode.find_by(id: @node_id)
      if node
        ids = [node.id] + node.descendant_ids
        parts << "archive_node_id IN [#{ids.join(',')}]"
      end
    end

    if @unitid.present?
      parts << "fonds_unitid = '#{@unitid}'"
    end

    if @unitid_prefix.present?
      parts << "fonds_unitid_prefix = '#{@unitid_prefix}'"
    end

    if @date_from.present? && @date_to.present?
      parts << "source_date_start_unix >= #{@date_from.to_time.to_i}"
      parts << "source_date_start_unix < #{@date_to.to_time.to_i}"
    end

    parts.join(' AND ').presence
  end

  def browse_counts
    Rails.cache.fetch('browse/tab_counts') do
      {
        fonds: ArchiveNode.where(parent_node_id: nil).count,
        origins: Origin.count,
        decades: ArchiveFile.where.not(source_date_start: nil).count
      }
    end
  end

  def load_browse_data
    case @tab
    when 'fonds'
      @letter = params[:letter]
      scope = ArchiveNode.where(parent_node_id: nil)
      @fonds_letters = Rails.cache.fetch('browse/fonds_letters_v2') do
        scope.pluck(Arel.sql('DISTINCT UPPER(SUBSTR(name, 1, 1))')).sort
      end
      scope = scope.where('UPPER(SUBSTR(name, 1, 1)) = ?', @letter) if @letter.present?
      @root_nodes = scope.order(:name).page(params[:page]).per(50)
    when 'origins'
      if params[:origin_id].present?
        @origin = Origin.find(params[:origin_id])
        @archive_files = @origin.archive_files.page(params[:page]).per(50)
      else
        @letter = params[:letter]
        all_origins = Origin.with_file_counts
        @origin_letters = Rails.cache.fetch('browse/origin_letters') do
          all_origins.map { |o| o.name[0]&.upcase }.compact.uniq.sort
        end
        filtered = @letter.present? ? all_origins.select { |o| o.name[0]&.upcase == @letter } : all_origins
        @origins = Kaminari.paginate_array(filtered).page(params[:page]).per(50)
      end
    when 'dates'
      if params[:from].present? && params[:to].present?
        @date_from = Date.parse(params[:from])
        @date_to = Date.parse(params[:to])
        @archive_files = ArchiveFile.in_date_range(@date_from, @date_to).page(params[:page]).per(50)
      else
        @period_counts = ArchiveFile.period_counts
      end
    end
  end
end
