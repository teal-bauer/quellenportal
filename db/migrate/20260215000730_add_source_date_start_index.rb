class AddSourceDateStartIndex < ActiveRecord::Migration[8.0]
  def change
    add_index :archive_files, :source_date_start
  end
end
