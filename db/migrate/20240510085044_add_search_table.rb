class AddSearchTable < ActiveRecord::Migration[7.1]
  def up
    execute(
      "CREATE VIRTUAL TABLE record_trigrams USING fts5(record_id, title, summary, call_number, parents, origin_names, tokenize = 'trigram')"
    )
  end

  def down
    execute('DROP TABLE IF EXISTS record_trigrams')
  end
end
