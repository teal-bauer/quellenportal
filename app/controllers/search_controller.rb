class SearchController < ApplicationController
  helper SearchHelper

  def index
    @total = ArchiveFile.cached_all_count
    @query = params[:q]
    @node_id = params[:node_id]
    @archive_node = ArchiveNode.find_by(id: @node_id) if @node_id.present?

    if @query.present?
      begin
        @trigrams =
          ArchiveFileTrigram
            .search(@query)
            .in_node(@node_id)
            .page(params[:page])
            .per(500)
            .includes(:archive_file)

        cache_key = "controllers/search/pagination_cache_#{helpers.query_cache_key @query}_node_#{@node_id}"
        @pagination_cache =
          Rails
            .cache
            .fetch(cache_key) do
              {
                total_count: @trigrams.total_count,
                total_pages: @trigrams.total_pages
              }
            end
      rescue ActiveRecord::StatementInvalid => e
        raise unless e.cause.is_a?(SQLite3::SQLException)
        @search_error = true
        @trigrams = ArchiveFileTrigram.none.page(1)
        @pagination_cache = { total_count: 0, total_pages: 0 }
      end
    else
      @tab = params[:tab]
      @browse_counts = browse_counts
      load_browse_data
    end
  end

  private

  def browse_counts
    Rails.cache.fetch("browse/tab_counts", expires_in: 24.hours) do
      {
        fonds: ArchiveNode.where(parent_node_id: nil).count,
        origins: Origin.count,
        decades: ArchiveFile.where.not(source_date_start: nil).count
      }
    end
  end

  def load_browse_data
    case @tab
    when "fonds"
      @letter = params[:letter]
      scope = ArchiveNode.where(parent_node_id: nil)
      @fonds_letters = scope.pluck(Arel.sql("DISTINCT UPPER(SUBSTR(name, 1, 1))")).sort
      scope = scope.where("UPPER(SUBSTR(name, 1, 1)) = ?", @letter) if @letter.present?
      @root_nodes = scope.order(:name).page(params[:page]).per(50)
    when "origins"
      if params[:origin_id].present?
        @origin = Origin.find(params[:origin_id])
        @archive_files = @origin.archive_files.page(params[:page]).per(50)
      else
        @letter = params[:letter]
        all_origins = Origin.with_file_counts
        @origin_letters = all_origins.map { |o| o.name[0]&.upcase }.compact.uniq.sort
        filtered = @letter.present? ? all_origins.select { |o| o.name[0]&.upcase == @letter } : all_origins
        @origins = Kaminari.paginate_array(filtered).page(params[:page]).per(50)
      end
    when "dates"
      if params[:from].present? && params[:to].present?
        @date_from = Date.parse(params[:from])
        @date_to = Date.parse(params[:to])
        @archive_files = ArchiveFile.in_date_range(@date_from, @date_to).page(params[:page]).per(50)
      else
        @decade_counts = ArchiveFile.decade_counts
      end
    end
  end
end
