require "test_helper"

class PanelHealthTest < ActiveSupport::TestCase
  setup do
    @booted_at = PanelHealth.booted_at
    PanelHealth.booted_at = 1.hour.ago
    Rails.cache.clear
  end

  teardown { PanelHealth.booted_at = @booted_at }

  def check(report, name) = report.checks.find { |c| c.name == name }

  test "alert evaluation is overdue when it hasn't finished for a few rounds" do
    PanelHealth.beat!(:alerts, at: 10.minutes.ago)

    report = PanelHealth.report

    assert_not report.ok?
    assert_equal [ :alerts ], report.stalled.map(&:name)
  end

  test "a recent beat is healthy" do
    PanelHealth.beat!(:alerts, at: 20.seconds.ago)

    assert PanelHealth.report.ok?
  end

  # A fresh process gets a grace period, even when the cache still holds an old beat from before it.
  test "counts from boot when the last beat predates this process" do
    PanelHealth.booted_at = 30.seconds.ago
    PanelHealth.beat!(:alerts, at: 2.days.ago)

    assert PanelHealth.report.ok?
  end

  test "status collection is only checked when there is an active app to poll" do
    assert_nil check(PanelHealth.report, :status_poll)

    ManagedApp.create!(name: "blog", config_yaml: file_fixture("simple_deploy.yml").read, destination: "production")
    PanelHealth.beat!(:alerts)

    assert_equal [ :status_poll ], PanelHealth.report.stalled.map(&:name)
  end

  test "rejects an unknown check name" do
    assert_raises(ArgumentError) { PanelHealth.beat!(:typo) }
  end
end
