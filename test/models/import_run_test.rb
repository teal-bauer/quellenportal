require "test_helper"

class ImportRunTest < ActiveSupport::TestCase
  setup do
    @run = ImportRun.create!(status: "pending", started_at: Time.current)
  end

  test "valid statuses" do
    ImportRun::STATUSES.each do |status|
      @run.status = status
      assert @run.valid?, "#{status} should be valid"
    end
  end

  test "invalid status rejected" do
    @run.status = "bogus"
    assert_not @run.valid?
  end

  test "active? returns true for in-progress statuses" do
    %w[pending preparing importing swapping].each do |status|
      @run.update!(status: status)
      assert @run.active?, "#{status} should be active"
    end
  end

  test "active? returns false for terminal statuses" do
    %w[completed failed cancelled].each do |status|
      @run.update!(status: status)
      assert_not @run.active?, "#{status} should not be active"
    end
  end

  test "active scope returns only active runs" do
    @run.update!(status: "importing")
    completed = ImportRun.create!(status: "completed")
    failed = ImportRun.create!(status: "failed")

    active = ImportRun.active
    assert_includes active, @run
    assert_not_includes active, completed
    assert_not_includes active, failed
  end

  test "mark_file_completed! increments counters and appends filename" do
    @run.update!(status: "importing", total_files: 5)

    @run.mark_file_completed!("file1.xml", records: 100)
    @run.reload

    assert_equal 1, @run.completed_files
    assert_equal 100, @run.total_records_imported
    assert_equal ["file1.xml"], @run.completed_filenames
    assert_nil @run.current_file

    @run.mark_file_completed!("file2.xml", records: 200)
    @run.reload

    assert_equal 2, @run.completed_files
    assert_equal 300, @run.total_records_imported
    assert_equal ["file1.xml", "file2.xml"], @run.completed_filenames
  end

  test "complete! sets status and finished_at" do
    @run.update!(status: "swapping", current_file: "test.xml")
    @run.complete!
    @run.reload

    assert_equal "completed", @run.status
    assert_nil @run.current_file
    assert_not_nil @run.finished_at
  end

  test "fail! sets status, error message, and finished_at" do
    @run.fail!("something broke")
    @run.reload

    assert_equal "failed", @run.status
    assert_equal "something broke", @run.error_message
    assert_not_nil @run.finished_at
  end

  test "cancel! sets status and finished_at" do
    @run.cancel!
    @run.reload

    assert_equal "cancelled", @run.status
    assert_nil @run.current_file
    assert_not_nil @run.finished_at
  end

  test "progress_percent with zero total" do
    assert_equal 0, @run.progress_percent
  end

  test "progress_percent with progress" do
    @run.update!(total_files: 10, completed_files: 3)
    assert_equal 30.0, @run.progress_percent
  end

  test "elapsed returns nil without started_at" do
    run = ImportRun.create!(status: "pending")
    assert_nil run.elapsed
  end

  test "elapsed returns duration" do
    @run.update!(started_at: 60.seconds.ago, finished_at: 10.seconds.ago)
    assert_in_delta 50.0, @run.elapsed, 1.0
  end

  test "recent scope returns limited ordered results" do
    5.times { |i| ImportRun.create!(status: "completed", created_at: i.days.ago) }
    assert_equal 10, ImportRun.recent.limit_value
    assert_equal ImportRun.order(created_at: :desc).first, ImportRun.recent.first
  end
end
