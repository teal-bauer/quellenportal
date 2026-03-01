class CreateImportRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :import_runs do |t|
      t.string :status, null: false, default: "pending"
      t.integer :total_files, default: 0
      t.integer :completed_files, default: 0
      t.integer :total_records_imported, default: 0
      t.string :current_file
      t.text :error_message
      t.json :completed_filenames, default: []
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end
  end
end
