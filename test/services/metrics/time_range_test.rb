require "test_helper"

class Metrics::TimeRangeTest < ActiveSupport::TestCase
  test "offers only ranges the retention can fill" do
    assert_equal %w[1h 6h 24h 7d], Metrics::TimeRange.keys

    with_collection_settings(retention: { days: 3 }) do
      assert_equal %w[1h 6h 24h], Metrics::TimeRange.keys
      assert_equal "1h", Metrics::TimeRange.new("7d").key, "a range beyond retention falls back to the default"
      assert_equal "24h", Metrics::TimeRange.new("24h").key
    end
  end
end
