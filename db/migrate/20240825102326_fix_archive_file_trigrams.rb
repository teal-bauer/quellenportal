class FixArchiveFileTrigrams < ActiveRecord::Migration[7.1]
  def up
    execute('DROP TABLE IF EXISTS archive_file_trigrams')
    execute(
      "CREATE VIRTUAL TABLE archive_file_trigrams USING fts5(archive_file_id, title, summary, call_number, parents, origin_names, tokenize = 'trigram')"
    )
  end
end
