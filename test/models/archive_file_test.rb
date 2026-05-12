require 'test_helper'

# ArchiveFile is no longer an AR model — records live in Meilisearch and are
# wrapped via ApplicationController#wrap_archive_file. These tests exercise
# the date-helper logic that wrap_archive_file attaches.
class ArchiveFileWrappingTest < ActiveSupport::TestCase
  def wrap(attrs)
    ApplicationController.new.send(:wrap_archive_file, attrs)
  end

  test 'source_dates with only start' do
    file = wrap(source_date_start: '1984-01-24')
    assert_equal ['1984-01-24'], file.source_dates
  end

  test 'source_dates with start and end' do
    file = wrap(source_date_start: '1984-01-24', source_date_end: '1985-10-01')
    assert_equal %w[1984-01-24 1985-10-01], file.source_dates
  end

  test 'source_dates collapses identical start/end to single entry' do
    file = wrap(source_date_start: '1984-01-24', source_date_end: '1984-01-24')
    assert_equal ['1984-01-24'], file.source_dates
  end

  test 'source_date_years with only start' do
    file = wrap(source_date_start: '2020-01-01')
    assert_equal ['2020'], file.source_date_years
  end

  test 'source_date_years collapses same-year range' do
    file = wrap(source_date_start: '2020-01-01', source_date_end: '2020-12-31')
    assert_equal ['2020'], file.source_date_years
  end

  test 'source_date_years across two years' do
    file = wrap(source_date_start: '2020-01-01', source_date_end: '2021-12-31')
    assert_equal %w[2020 2021], file.source_date_years
  end

  test 'wrap returns nil for nil doc' do
    assert_nil wrap(nil)
  end
end
