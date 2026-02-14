class SearchController < ApplicationController
  helper SearchHelper

  def index
    @total = ArchiveFile.cached_all_count
    @query = params[:q]
    @node_id = params[:node_id]
    @archive_node = ArchiveNode.find_by(id: @node_id) if @node_id.present?

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
  end
end
