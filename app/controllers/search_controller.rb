class SearchController < ApplicationController
  helper SearchHelper

  def index
    @repository = MeilisearchRepository.new
    @query = params[:q].presence
    @node_id = params[:node_id]
    @total_count = 0
    @unitid = params[:unitid]
    @unitid_prefix = params[:unitid_prefix]
    @fonds_name = params[:fonds_name]
    @date_from = params[:from].present? ? Date.parse(params[:from]) : nil
    @date_to = params[:to].present? ? Date.parse(params[:to]) : nil
    
    # Retrieve node metadata from Meilisearch if ID is present
    if @node_id.present?
      @archive_node = @repository.get_node(@node_id)
      # Wrap in OpenStruct to mimic AR object
      if @archive_node
        @archive_node = OpenStruct.new(@archive_node)
        # Add parents helper if missing (should be in metadata though)
        unless @archive_node.respond_to?(:parents)
          @archive_node.parents = []
        end
      end
    end

    if @query.present?
      begin
        filter = build_meilisearch_filter
        sort = params[:sort] == 'call_number' ? ['call_number:asc'] : nil

        search_opts = {
          filter: filter,
          facets: %w[fonds_name fonds_unitid fonds_unitid_prefix decade],
          sort: sort,
          hitsPerPage: 100,
          page: (params[:page] || 1).to_i
        }.compact

        # Use Repository for search
        results = @repository.search_files(@query, search_opts)
        
        @results = Kaminari.paginate_array(
          results['hits'].map { |h| wrap_archive_file(h) },
          total_count: results['totalHits'] || results['estimatedTotalHits']
        ).page(params[:page]).per(100)

        @facets = results['facetDistribution']
        @total_count = results['totalHits'] || results['estimatedTotalHits'] || 0

        @fonds_id_map = {}
      rescue => e
        Rails.logger.error "Meilisearch error: #{e.class}: #{e.message}"
        @search_error = true
        @results = Kaminari.paginate_array([]).page(1)
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
      parts << "ancestor_ids = #{MeilisearchRepository.quote(@node_id)}"
    end

    if @unitid.present?
      parts << "fonds_unitid = #{MeilisearchRepository.quote(@unitid)}"
    end

    if @unitid_prefix.present?
      parts << "fonds_unitid_prefix = #{MeilisearchRepository.quote(@unitid_prefix)}"
    end

    if @fonds_name.present?
      parts << "fonds_name = #{MeilisearchRepository.quote(@fonds_name)}"
    end

    if @date_from.present? && @date_to.present?
      start_ts = @date_from.to_time.to_i
      end_ts = @date_to.to_time.to_i
      parts << "(source_date_start_unix >= #{start_ts} AND source_date_start_unix < #{end_ts} OR source_date_end_unix >= #{start_ts} AND source_date_end_unix < #{end_ts})"
    end

    parts.join(' AND ').presence
  end

  def browse_counts
    # Get stats directly from Meilisearch
    stats = @repository.stats
    {
      fonds: stats[:nodes],   # This might count ALL nodes, we may need a specific query for "roots"
      origins: stats[:origins],
      decades: stats[:files]  # Approximation
    }
  end

  def load_browse_data
    case @tab
    when 'fonds'
      @letter = params[:letter]
      @fonds_sort = params[:fonds_sort] || 'name'
      
      # Use the repository's dedicated method which handles the filter and sort
      response = @repository.root_nodes(
        page: (params[:page]||1).to_i, 
        letter: @letter, 
        sort_by: @fonds_sort
      )
      
      @root_nodes = Kaminari.paginate_array(
        response['hits'].map { |h| OpenStruct.new(h) },
        total_count: response['totalHits'] || response['estimatedTotalHits']
      ).page(params[:page]).per(50)
      
      # Fetch available letters dynamically from facets
      @fonds_letters = @repository.fonds_letters(sort_by: @fonds_sort)
      
    when 'origins'
      if params[:origin_id].present?
        # Drilldown into an origin
        origin = @repository.get_origin(params[:origin_id])
        @origin = OpenStruct.new(origin)
        
        if @origin
          response = @repository.search_files("", 
            filter: "origin_names = #{MeilisearchRepository.quote(@origin.name)}", 
            hitsPerPage: 50, 
            page: (params[:page]||1).to_i
          )
          @archive_files = Kaminari.paginate_array(
            response['hits'].map { |h| wrap_archive_file(h) },
            total_count: response['totalHits'] || response['estimatedTotalHits']
          ).page(params[:page]).per(50)
        end
      else
        @letter = params[:letter]
        response = @repository.all_origins(page: (params[:page]||1).to_i, letter: @letter)
        
        @origins = Kaminari.paginate_array(
          response['hits'].map { |h| OpenStruct.new(h) },
          total_count: response['totalHits']
        ).page(params[:page]).per(50)
        
        @origin_letters = @repository.origin_letters
      end
    when 'dates'
      if params[:from].present? && params[:to].present?
        @date_from = Date.parse(params[:from])
        @date_to = Date.parse(params[:to])
        # Use Meilisearch filter for date range
        filter = "source_date_start_unix >= #{@date_from.to_time.to_i} AND source_date_start_unix < #{@date_to.to_time.to_i}"
        response = @repository.search_files("", filter: filter, hitsPerPage: 50, page: (params[:page]||1).to_i)
        
        @archive_files = Kaminari.paginate_array(
          response['hits'].map { |h| wrap_archive_file(h) },
          total_count: response['totalHits']
        ).page(params[:page]).per(50)
      else
        # Period counts
        # Use the new 'period' facet for better grouping (centuries vs decades)
        response = @repository.search_files("", facets: ['period'], hitsPerPage: 0)
        
        if response['facetDistribution'] && response['facetDistribution']['period']
          @period_counts = response['facetDistribution']['period'].map do |period, count|
            year = period.to_i
            span = year < 1800 ? 100 : 10
            { 'period' => year, 'span' => span, 'file_count' => count }
          end.sort_by { |p| p['period'] }
        else
          @period_counts = []
        end
      end
    end
  end
end
