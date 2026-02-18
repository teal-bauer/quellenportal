class ArchiveNodesController < ApplicationController
  def show
    @repository = MeilisearchRepository.new
    doc = @repository.get_node(params[:id])
    if doc.nil?
      render plain: "Not found", status: 404
      return
    end
    
    @archive_node = OpenStruct.new(doc)
    
    respond_to do |format|
      format.html do
        @browse_counts = browse_counts
        # Fetch immediate children
        child_resp = @repository.search_nodes("", filter: "parent_node_id = '#{@archive_node.id}'", sort: ['name:asc'], hitsPerPage: 1000)
        @child_nodes = child_resp['hits'].map { |h| OpenStruct.new(h) }
        
        # Fetch file counts for these children
        # We can search files where ancestor_ids contains any of these child IDs
        # For now, let's just get counts for immediate files of this node
        file_resp = @repository.search_files("", filter: "archive_node_id = '#{@archive_node.id}'", hitsPerPage: 0, facets: ['archive_node_id'])
        @file_counts = file_resp['facetDistribution']&.dig('archive_node_id') || {}
      end
      format.json { render json: archive_node_payload }
      format.xml { render xml: archive_node_payload.to_xml(root: 'archive_node') }
    end
  end

  private

  def browse_counts
    stats = @repository.stats
    {
      fonds: stats[:nodes],
      origins: stats[:origins],
      decades: stats[:files]
    }
  end

  def archive_node_payload
    # Fetch children and files for the payload
    child_resp = @repository.search_nodes("", filter: "parent_node_id = '#{@archive_node.id}'", sort: ['name:asc'])
    file_resp = @repository.search_files("", filter: "archive_node_id = '#{@archive_node.id}'", sort: ['call_number:asc'])
    
    {
      id: @archive_node.id,
      name: @archive_node.name,
      level: @archive_node.level,
      parents: @archive_node.parents || [],
      child_nodes: child_resp['hits'].map { |h| { id: h['id'], name: h['name'], level: h['level'] } },
      archive_files: file_resp['hits'].map do |f|
        {
          id: f['id'],
          title: f['title'],
          call_number: f['call_number'],
          source_date_text: f['source_date_text'],
          summary: f['summary']
        }
      end
    }
  end
end
