class UseUuidPrimaryKeys < ActiveRecord::Migration[8.0]
  def change
    # ArchiveNodes
    create_table :archive_nodes_new, id: :string do |t|
      t.string :parent_node_id
      t.string :name
      t.string :level
      t.string :unitid
      t.string :unitdate
      t.json :physdesc
      t.string :langmaterial
      t.json :origination
      t.json :repository
      t.text :scopecontent
      t.text :relatedmaterial
      t.text :prefercite
      t.timestamps
    end
    add_index :archive_nodes_new, :parent_node_id

    # ArchiveFiles
    create_table :archive_files_new, id: :string do |t|
      t.string :archive_node_id
      t.string :title
      t.json :parents, null: false
      t.string :call_number
      t.string :source_date_text
      t.date :source_date_start
      t.date :source_date_end
      t.date :source_date_start_uncorrected
      t.date :source_date_end_uncorrected
      t.string :link
      t.string :location
      t.string :language_code
      t.text :summary
      t.timestamps
    end
    add_index :archive_files_new, :archive_node_id
    add_index :archive_files_new, :call_number
    add_index :archive_files_new, :source_date_start
    add_index :archive_files_new, :title
    add_index :archive_files_new, [:title, :summary]

    # Originations (join table) - recreate with string foreign key
    create_table :originations_new, id: false do |t|
      t.string :archive_file_id, null: false
      t.bigint :origin_id, null: false
    end
    add_index :originations_new, [:archive_file_id, :origin_id], unique: true

    # Drop old tables and rename new ones
    # We don't migrate data because the user wants to clean up "old nodes" and re-import anyway
    drop_table :originations
    drop_table :archive_files
    drop_table :archive_nodes

    rename_table :archive_nodes_new, :archive_nodes
    rename_table :archive_files_new, :archive_files
    rename_table :originations_new, :originations
  end
end
