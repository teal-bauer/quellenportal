class AddUncorrectedDateColumns < ActiveRecord::Migration[8.0]
  def change
    add_column :archive_files, :source_date_start_uncorrected, :date
    add_column :archive_files, :source_date_end_uncorrected, :date
  end
end
