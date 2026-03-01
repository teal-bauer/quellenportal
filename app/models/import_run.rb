class ImportRun < ApplicationRecord
  STATUSES = %w[pending preparing importing swapping completed failed cancelled].freeze

  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: %w[pending preparing importing swapping]) }
  scope :recent, -> { order(created_at: :desc).limit(10) }

  def active?
    %w[pending preparing importing swapping].include?(status)
  end

  def mark_file_completed!(filename, records:)
    with_lock do
      filenames = completed_filenames || []
      filenames << filename
      update!(
        completed_filenames: filenames,
        completed_files: filenames.size,
        total_records_imported: (total_records_imported || 0) + records,
        current_file: nil
      )
    end
  end

  def fail!(message)
    update!(status: "failed", error_message: message, finished_at: Time.current)
  end

  def complete!
    update!(status: "completed", current_file: nil, finished_at: Time.current)
  end

  def cancel!
    update!(status: "cancelled", current_file: nil, finished_at: Time.current)
  end

  def progress_percent
    return 0 if total_files.nil? || total_files.zero?
    ((completed_files.to_f / total_files) * 100).round(1)
  end

  def elapsed
    return nil unless started_at
    (finished_at || Time.current) - started_at
  end
end
