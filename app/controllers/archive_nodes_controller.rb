class ArchiveNodesController < ApplicationController
  def show
    @archive_node = ArchiveNode.find(params[:id])
    respond_to do |format|
      format.html do
        @browse_counts = browse_counts
        @archive_node = drill_down(@archive_node)
        if @archive_node.id != params[:id].to_i
          redirect_to archive_node_path(@archive_node), status: :moved_permanently
          return
        end
        parent_chain = @archive_node.parents
        child_ids = ArchiveNode.where(parent_node_id: parent_chain.map(&:id)).pluck(:id)
        @file_counts = ArchiveFile.where(archive_node_id: child_ids + [parent_chain.first.id]).group(:archive_node_id).count
      end
      format.json { render json: archive_node_payload }
      format.xml { render xml: archive_node_payload.to_xml(root: "archive_node") }
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

  def drill_down(node)
    while node.archive_files.none? && node.child_nodes.count == 1
      node = node.child_nodes.first
    end
    node
  end

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
