class SearchController < ApplicationController
  helper SearchHelper

  def index
    @total = ArchiveFile.cached_all_count
    @query = params[:q]
    @node_id = params[:node_id]
    @archive_node = ArchiveNode.find_by(id: @node_id) if @node_id.present?

    if @query.present?
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
      @root_nodes = ArchiveNode.where(parent_node_id: nil).order(:name).page(params[:page]).per(50)
    when "origins"
      if params[:origin_id].present?
        @origin = Origin.find(params[:origin_id])
        @archive_files = @origin.archive_files.page(params[:page]).per(50)
      else
        @origins = Kaminari.paginate_array(Origin.with_file_counts).page(params[:page]).per(50)
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
