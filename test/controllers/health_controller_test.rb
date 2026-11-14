require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @booted_at = PanelHealth.booted_at
    PanelHealth.booted_at = 1.hour.ago
    Rails.cache.clear
  end

  teardown { PanelHealth.booted_at = @booted_at }

  test "answers 200 without signing in while background work is on time" do
    PanelHealth.beat!(:alerts)

    get panel_health_path

    assert_response :ok
    assert_equal "ok", response.parsed_body["status"]
    assert response.parsed_body.dig("checks", "alerts", "ok")
  end

  test "answers 503 naming the stalled work" do
    PanelHealth.beat!(:alerts, at: 10.minutes.ago)

    get panel_health_path

    assert_response :service_unavailable
    assert_equal "stalled", response.parsed_body["status"]
    assert_not response.parsed_body.dig("checks", "alerts", "ok")
  end

  test "signed-in pages warn while background work is stalled" do
    sign_in_as(users(:one))
    PanelHealth.beat!(:alerts, at: 10.minutes.ago)

    get audit_logs_path

    assert_select ".panel-health", /告警评估|alert evaluation/
  end

  test "no warning while it is on time" do
    sign_in_as(users(:one))
    PanelHealth.beat!(:alerts)

    get audit_logs_path

    assert_select ".panel-health", count: 0
  end
end
