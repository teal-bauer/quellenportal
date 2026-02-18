class AddMetadataToArchiveNodes < ActiveRecord::Migration[8.0]
  def change
    add_column :archive_nodes, :unitid, :string
    add_column :archive_nodes, :unitdate, :string
    add_column :archive_nodes, :physdesc, :text
    add_column :archive_nodes, :langmaterial, :string
    add_column :archive_nodes, :origination, :text
    add_column :archive_nodes, :repository, :text
    add_column :archive_nodes, :scopecontent, :text
    add_column :archive_nodes, :relatedmaterial, :text
    add_column :archive_nodes, :prefercite, :text
  end
end
