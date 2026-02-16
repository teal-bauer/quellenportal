class RecreateFts5WithFacetColumns < ActiveRecord::Migration[8.0]
  def up
    execute "DROP TABLE IF EXISTS archive_file_trigrams"
    execute <<~SQL
      CREATE VIRTUAL TABLE archive_file_trigrams USING fts5(
        archive_file_id UNINDEXED,
        archive_node_id UNINDEXED,
        fonds_id UNINDEXED,
        fonds_name UNINDEXED,
        decade UNINDEXED,
        title, summary, call_number, parents, origin_names,
        tokenize = 'trigram'
      )
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS archive_file_trigrams"
    execute <<~SQL
      CREATE VIRTUAL TABLE archive_file_trigrams USING fts5(
        archive_file_id UNINDEXED,
        archive_node_id UNINDEXED,
        title, summary, call_number, parents, origin_names,
        tokenize = 'trigram'
      )
    SQL
  end
end
