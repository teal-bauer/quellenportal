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
        
        # Prepare Tree Menu Data
        # @archive_node.parents contains the chain ABOVE the current node
        @parents = (@archive_node.parents || []).map { |p| OpenStruct.new(p) }
        
        # The full path from root to current node
        path_nodes = @parents + [@archive_node]
        root_node = path_nodes.first
        
        @levels = []
        
        # Level 0: Just the single root of this tree
        @levels << [root_node]
        
        # Subsequent levels: Children of each node in the path (up to the current node)
        path_nodes.each do |node|
          children_resp = @repository.search_nodes("", filter: "parent_node_id = #{MeilisearchRepository.quote(node.id)}", sort: ['name:asc'], hitsPerPage: 1000)
          children = children_resp['hits'].map { |h| OpenStruct.new(h) }
          @levels << children if children.any?
        end

        # Fetch file counts for all nodes in the visible menu levels
        all_visible_node_ids = @levels.flatten.map(&:id)
        if all_visible_node_ids.any?
          # Use quoted IDs for the IN filter
          quoted_ids = all_visible_node_ids.map { |id| MeilisearchRepository.quote(id) }
          count_resp = @repository.search_files("", 
            filter: "archive_node_id IN [#{quoted_ids.join(',')}]", 
            hitsPerPage: 0, 
            facets: ['archive_node_id']
          )
          @file_counts = count_resp['facetDistribution']&.dig('archive_node_id') || {}
        else
          @file_counts = {}
        end

        # Files for the current node
        current_files_resp = @repository.search_files("", filter: "archive_node_id = #{MeilisearchRepository.quote(@archive_node.id)}", sort: ['call_number:asc'], hitsPerPage: 100)
        @archive_files = current_files_resp['hits'].map { |h| OpenStruct.new(h) }
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
    child_resp = @repository.search_nodes("", filter: "parent_node_id = #{MeilisearchRepository.quote(@archive_node.id)}", sort: ['name:asc'])
    file_resp = @repository.search_files("", filter: "archive_node_id = #{MeilisearchRepository.quote(@archive_node.id)}", sort: ['call_number:asc'])
    
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
