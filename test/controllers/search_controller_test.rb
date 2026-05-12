require 'test_helper'

class SearchControllerTest < ActionDispatch::IntegrationTest
  # build_meilisearch_filter is private; exercise it via send to avoid
  # spinning up Meilisearch for filter-string assertions.

  setup do
    @controller = SearchController.new
  end

  test "date filter upper bound is start of day after :to (inclusive)" do
    @controller.instance_variable_set(:@date_from, Date.new(2026, 1, 1))
    @controller.instance_variable_set(:@date_to, Date.new(2026, 5, 12))
    filter = @controller.send(:build_meilisearch_filter)

    next_day_ts = Date.new(2026, 5, 13).to_time.to_i
    assert_includes filter, "< #{next_day_ts}"
    refute_includes filter, "< #{Date.new(2026, 5, 12).to_time.to_i}"
  end

  test "date filter supports open-ended from only" do
    @controller.instance_variable_set(:@date_from, Date.new(2026, 1, 1))
    @controller.instance_variable_set(:@date_to, nil)
    filter = @controller.send(:build_meilisearch_filter)

    lower_ts = Date.new(2026, 1, 1).to_time.to_i
    assert_includes filter, ">= #{lower_ts}"
    refute_match(/source_date_\w+_unix < /, filter)
  end

  test "date filter supports open-ended to only" do
    @controller.instance_variable_set(:@date_from, nil)
    @controller.instance_variable_set(:@date_to, Date.new(2026, 5, 12))
    filter = @controller.send(:build_meilisearch_filter)

    upper_ts = Date.new(2026, 5, 13).to_time.to_i
    assert_includes filter, "< #{upper_ts}"
    refute_match(/source_date_\w+_unix >= /, filter)
  end

  test "safe_parse_date returns nil on garbage" do
    assert_nil @controller.send(:safe_parse_date, "garbage")
    assert_nil @controller.send(:safe_parse_date, "")
    assert_nil @controller.send(:safe_parse_date, nil)
    assert_equal Date.new(2026, 5, 12), @controller.send(:safe_parse_date, "2026-05-12")
  end
end
