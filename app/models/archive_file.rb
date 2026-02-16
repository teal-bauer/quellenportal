# == Schema Information
#
# Table name: archive_files
#
#  id                            :integer          not null, primary key
#  call_number                   :string
#  language_code                 :string
#  link                          :string
#  location                      :string
#  parents                       :json             not null
#  source_date_end               :date
#  source_date_end_uncorrected   :date
#  source_date_start             :date
#  source_date_start_uncorrected :date
#  source_date_text              :string
#  summary                       :string
#  title                         :string
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  archive_node_id               :integer
#  source_id                     :string
#
# Indexes
#
#  index_archive_files_on_archive_node_id    (archive_node_id)
#  index_archive_files_on_call_number        (call_number)
#  index_archive_files_on_source_date_start  (source_date_start)
#  index_archive_files_on_source_id          (source_id) UNIQUE
#  index_archive_files_on_summary            (summary)
#  index_archive_files_on_title              (title)
#  index_archive_files_on_title_and_summary  (title,summary)
#
class ArchiveFile < ApplicationRecord
  belongs_to :archive_node

  has_many :originations, inverse_of: :archive_file
  has_many :origins, through: :originations

  has_one :archive_file_trigram

  after_create :insert_trigram
  after_update :update_trigram
  after_destroy :delete_trigram

  scope :in_date_range, ->(from, to) {
    where(
      "source_date_start >= :from AND source_date_start < :to
       OR source_date_start_uncorrected >= :from AND source_date_start_uncorrected < :to",
      from: from, to: to
    )
  }

  def self.update_cached_all_count
    count = self.all.count
    CachedCount.find_or_create_by(model: self.name, scope: :all).update(
      count: count
    )
  end

  def self.cached_all_count
    CachedCount.find_by(model: self.name, scope: :all)&.count
  end

  def self.decade_counts
    Rails.cache.fetch("archive_files/decade_counts", expires_in: 24.hours) do
      connection.select_all(<<~SQL).to_a
        SELECT (CAST(strftime('%Y', source_date_start) AS INTEGER) / 10) * 10 AS decade,
               COUNT(*) AS file_count
        FROM archive_files
        WHERE source_date_start IS NOT NULL
        GROUP BY decade
        ORDER BY decade
      SQL
    end
  end

  def self.reindex(show_progress = false)
    start = Time.now if show_progress

    connection.execute("DELETE FROM archive_file_trigrams")
    connection.execute(<<~SQL)
      INSERT INTO archive_file_trigrams(
        archive_file_id, archive_node_id,
        fonds_id, fonds_name, decade,
        title, summary, call_number, parents, origin_names
      )
      SELECT
        af.id, af.archive_node_id,
        CAST(json_extract(af.parents, '$[0].id') AS INTEGER),
        json_extract(af.parents, '$[0].name'),
        CASE WHEN af.source_date_start IS NOT NULL
          THEN (CAST(strftime('%Y', af.source_date_start) AS INTEGER) / 10) * 10
          ELSE NULL END,
        af.title, af.summary, af.call_number,
        (SELECT GROUP_CONCAT(json_extract(value, '$.name'), ' ')
         FROM json_each(af.parents)),
        COALESCE((SELECT GROUP_CONCAT(o.name, ' ')
         FROM originations ori JOIN origins o ON ori.origin_id = o.id
         WHERE ori.archive_file_id = af.id), '')
      FROM archive_files af
    SQL

    puts "Reindexing took #{Time.now - start} seconds" if show_progress
  end

  def source_dates
    if source_date_end.blank? || source_date_start == source_date_end
      return [source_date_start.to_s]
    end

    [source_date_start.to_s, source_date_end.to_s]
  end

  def source_date_years
    return [] if source_date_start.blank? && source_date_end.blank?

    if source_date_end.blank? || source_date_start.year == source_date_end.year
      return [source_date_start.year.to_s]
    end

    [source_date_start.year.to_s, source_date_end.year.to_s]
  end

  def insert_trigram
    fonds = parents&.first
    decade_val = source_date_start ? (source_date_start.year / 10) * 10 : nil

    trigram_attrs = {
      archive_file_id: id,
      archive_node_id: archive_node_id,
      fonds_id: fonds&.dig("id"),
      fonds_name: fonds&.dig("name"),
      decade: decade_val,
      title: title,
      summary: summary,
      call_number: call_number,
      parents: parents.map { |p| p['name'] }.join(" "),
      origin_names: origins.pluck(:name).join(" ")
    }

    values = trigram_attrs.values.map { |v| ArchiveFile.connection.quote(v) }
    sql_insert = <<~SQL.strip
      INSERT INTO archive_file_trigrams(#{trigram_attrs.keys.join(", ")}) VALUES(#{values.join(", ")});
    SQL
    self.class.connection.execute(sql_insert)
  end

  def delete_trigram
    delete_statement =
      "DELETE FROM archive_file_trigrams WHERE archive_file_id = #{attributes["id"]}"
    self.class.connection.execute(delete_statement)
  end

  def update_trigram
    # Not very efficient, but fine for now as this should basically never happen
    delete_trigram
    insert_trigram
  end
end
