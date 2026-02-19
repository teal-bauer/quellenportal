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
        # parents is an array of hashes: [{id: '...', name: '...', unitid: '...'}, ...]
        @parents = (@archive_node.parents || []).map { |p| OpenStruct.new(p) }
        
        # We need siblings for each level of the hierarchy to build the menu
        # Level 0: Root nodes
        # Level N: Children of parent[N-1]
        
        @levels = []
        
        # Level 0: Root siblings
        root_resp = @repository.search_nodes("", filter: "level = 'fonds'", sort: ['name:asc'], hitsPerPage: 1000)
        @levels << root_resp['hits'].map { |h| OpenStruct.new(h) }
        
        # Subsequent levels: Siblings of each parent in the chain
        @parents.each do |parent|
          siblings_resp = @repository.search_nodes("", filter: "parent_node_id = '#{parent.id}'", sort: ['name:asc'], hitsPerPage: 1000)
          @levels << siblings_resp['hits'].map { |h| OpenStruct.new(h) }
        end
        
        # Final level: Children of the current node
        child_resp = @repository.search_nodes("", filter: "parent_node_id = '#{@archive_node.id}'", sort: ['name:asc'], hitsPerPage: 1000)
        @child_nodes = child_resp['hits'].map { |h| OpenStruct.new(h) }
        # Only add the final level if there are children
        @levels << @child_nodes if @child_nodes.any?

        # Fetch file counts for all nodes in the visible menu levels
        all_visible_node_ids = @levels.flatten.map(&:id)
        if all_visible_node_ids.any?
          # We can get counts by faceting on archive_node_id for files matching these IDs
          # Using a filter with many IDs might be slow, but let's try
          count_resp = @repository.search_files("", 
            filter: "archive_node_id IN [#{all_visible_node_ids.join(',')}]", 
            hitsPerPage: 0, 
            facets: ['archive_node_id']
          )
          @file_counts = count_resp['facetDistribution']&.dig('archive_node_id') || {}
        else
          @file_counts = {}
        end

        # Files for the current node
        current_files_resp = @repository.search_files("", filter: "archive_node_id = '#{@archive_node.id}'", sort: ['call_number:asc'], hitsPerPage: 100)
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
