class ArchiveNodesController < ApplicationController
  def show
    @archive_node = ArchiveNode.find(params[:id])
    respond_to do |format|
      format.html
      format.json { render json: archive_node_payload }
      format.xml { render xml: archive_node_payload.to_xml(root: "archive_node") }
    end
  end

  private

  def archive_node_payload
    {
      id: @archive_node.id,
      name: @archive_node.name,
      level: @archive_node.level,
      source_id: @archive_node.source_id,
      parents:
        @archive_node.parents.map { |n|
          { id: n.id, name: n.name, level: n.level }
        },
      child_nodes:
        @archive_node.child_nodes.map { |n|
          { id: n.id, name: n.name, level: n.level }
        },
      archive_files:
        @archive_node.archive_files.map { |f|
          {
            id: f.id,
            title: f.title,
            call_number: f.call_number,
            source_date_text: f.source_date_text,
            summary: f.summary
          }
        }
    }
  end
end
