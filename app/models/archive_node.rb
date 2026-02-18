# == Schema Information
#
# Table name: archive_nodes
#
#  id              :string           not null, primary key
#  langmaterial    :string
#  level           :string
#  name            :string
#  origination     :json
#  physdesc        :json
#  prefercite      :text
#  relatedmaterial :text
#  repository      :json
#  scopecontent    :text
#  unitdate        :string
#  unitid          :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  parent_node_id  :string
#
# Indexes
#
#  index_archive_nodes_on_parent_node_id  (parent_node_id)
#
class ArchiveNode < ApplicationRecord
  self.primary_key = :id

  belongs_to :parent_node, class_name: 'ArchiveNode', optional: true

  has_many :child_nodes, class_name: 'ArchiveNode', foreign_key: 'parent_node_id'
  has_many :archive_files

  attribute :physdesc, :json
  attribute :origination, :json
  attribute :repository, :json

  def parents
    next_node = self
    parents = []

    while next_node.present?
      parents << next_node
      next_node = next_node.parent_node
    end

    parents.reverse
  end

  def descendant_ids
    ids = []
    nodes_to_process = child_nodes.to_a

    while nodes_to_process.any?
      node = nodes_to_process.shift
      ids << node.id
      nodes_to_process.concat(node.child_nodes.to_a)
    end

    ids
  end
end
