require "test_helper"

class ArchiveNodeTest < ActiveSupport::TestCase
  def setup
    BundesarchivImporter.new("test/fixtures/files/dataset-tiny").run
  end

  test "descendant_ids includes child nodes" do
    # Find a node with children
    parent_node = ArchiveNode.joins(:child_nodes).distinct.first
    descendant_ids = parent_node.descendant_ids

    # All direct children should be in descendants
    parent_node.child_nodes.each do |child|
      assert_includes descendant_ids, child.id
    end
  end

  test "descendant_ids includes grandchildren" do
    # Find a node whose children also have children
    grandparent = ArchiveNode.find_by(parent_node_id: nil)
    next unless grandparent

    descendant_ids = grandparent.descendant_ids

    # Check that grandchildren are included
    grandparent.child_nodes.each do |child|
      child.child_nodes.each do |grandchild|
        assert_includes descendant_ids, grandchild.id
      end
    end
  end

  test "descendant_ids returns empty array for leaf node" do
    # Find a node with no children by checking child_nodes count
    leaf_node = ArchiveNode.all.find { |n| n.child_nodes.empty? }
    assert_not_nil leaf_node, "Should have at least one leaf node"
    assert_equal [], leaf_node.descendant_ids
  end

  test "parents returns nodes from root to self" do
    deepest_node = ArchiveNode.order(:id).last
    parents = deepest_node.parents

    assert_equal deepest_node, parents.last
    assert_nil parents.first.parent_node_id
  end
end
