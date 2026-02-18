# == Schema Information
#
# Table name: archive_files
#
#  id                            :string           not null, primary key
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
#  summary                       :text
#  title                         :string
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  archive_node_id               :string
#
# Indexes
#
#  index_archive_files_on_archive_node_id    (archive_node_id)
#  index_archive_files_on_call_number        (call_number)
#  index_archive_files_on_source_date_start  (source_date_start)
#  index_archive_files_on_title              (title)
#  index_archive_files_on_title_and_summary  (title,summary)
#
class ArchiveFile < ApplicationRecord
  include MeiliSearch::Rails

  self.primary_key = :id

  belongs_to :archive_node

  has_many :originations, inverse_of: :archive_file
  has_many :origins, through: :originations

  meilisearch auto_index: false, auto_remove: false, check_settings: false do
    attribute :title, :summary, :call_number
    attribute(:parent_names) { parents&.map { |p| p['name'] }&.join(' ') || '' }
    attribute(:origin_names) { origins.pluck(:name).join(' ') }
    attribute(:fonds_id) { parents&.first&.dig('id') }
    attribute(:fonds_name) { parents&.first&.dig('name') }
    attribute(:fonds_unitid) { parents&.first&.dig('unitid') }
    attribute(:fonds_unitid_prefix) { parents&.first&.dig('unitid')&.split(' ')&.first }
    attribute(:decade) { source_date_start ? (source_date_start.year / 10) * 10 : nil }
    attribute(:archive_node_id) { archive_node_id }
    attribute(:source_date_start_unix) { source_date_start&.to_time&.to_i }

    searchable_attributes %i[title summary call_number parent_names origin_names]
    filterable_attributes %i[fonds_id fonds_name fonds_unitid fonds_unitid_prefix decade archive_node_id source_date_start_unix]
    sortable_attributes [:call_number]

    faceting max_values_per_facet: 100
    pagination max_total_hits: 100_000
  end

  scope :in_date_range, lambda { |from, to|
    where(
      "source_date_start >= :from AND source_date_start < :to
       OR source_date_start_uncorrected >= :from AND source_date_start_uncorrected < :to",
      from: from, to: to
    )
  }

  def self.update_cached_all_count
    count = all.count
    CachedCount.find_or_create_by(model: name, scope: :all).update(
      count: count
    )
  end

  def self.cached_all_count
    CachedCount.find_by(model: name, scope: :all)&.count
  end

  def self.period_counts
    Rails.cache.fetch('archive_files/decade_counts') do
      connection.select_all(<<~SQL).to_a
        SELECT
          CASE
            WHEN CAST(strftime('%Y', source_date_start) AS INTEGER) < 1800
            THEN (CAST(strftime('%Y', source_date_start) AS INTEGER) / 100) * 100
            ELSE (CAST(strftime('%Y', source_date_start) AS INTEGER) / 10) * 10
          END AS period,
          CASE
            WHEN CAST(strftime('%Y', source_date_start) AS INTEGER) < 1800
            THEN 100
            ELSE 10
          END AS span,
          COUNT(*) AS file_count
        FROM archive_files
        WHERE source_date_start IS NOT NULL
        GROUP BY period, span
        ORDER BY period
      SQL
    end
  end

  def source_dates
    return [source_date_start.to_s] if source_date_end.blank? || source_date_start == source_date_end

    [source_date_start.to_s, source_date_end.to_s]
  end

  def source_date_years
    return [] if source_date_start.blank? && source_date_end.blank?

    return [source_date_start.year.to_s] if source_date_end.blank? || source_date_start.year == source_date_end.year

    [source_date_start.year.to_s, source_date_end.year.to_s]
  end
end
