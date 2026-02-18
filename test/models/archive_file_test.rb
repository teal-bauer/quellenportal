require 'test_helper'

class ArchiveFileTest < ActiveSupport::TestCase
  test 'source_dates' do
    archive_file = ArchiveFile.new(source_date_start: Date.new(1984, 1, 24))
    assert_equal ['1984-01-24'], archive_file.source_dates

    archive_file.source_date_end = Date.new(1985, 10, 1)
    assert_equal %w[1984-01-24 1985-10-01], archive_file.source_dates
  end

  test 'source_date_years' do
    archive_file = ArchiveFile.new(source_date_start: Date.new(2020, 1, 1))
    assert_equal ['2020'], archive_file.source_date_years

    archive_file.source_date_end = Date.new(2020, 12, 31)
    assert_equal ['2020'], archive_file.source_date_years

    archive_file.source_date_end = Date.new(2021, 12, 31)
    assert_equal %w[2020 2021], archive_file.source_date_years
  end
end
