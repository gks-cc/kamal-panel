require "test_helper"

class PruneObservationsJobTest < ActiveSupport::TestCase
  setup do
    @app = ManagedApp.create!(name: "blog", config_yaml: file_fixture("simple_deploy.yml").read, destination: "production")
  end

  def metric(age)
    HostMetric.create!(managed_app: @app, host: "127.0.0.1", sampled_at: age.ago, cpu_percent: 1)
  end

  def observation(age, reachable: true)
    Observation.create!(managed_app: @app, host: "127.0.0.1", observed_at: age.ago, reachable:,
                        container_name: "blog-web-#{age.to_i}", docker_status: "running", role: "web", version: "v1")
  end

  test "keeps exactly retention.days of data" do
    old_metric, recent_metric = metric(4.days), metric(2.days)
    old_observation, recent_observation = observation(4.days), observation(2.days)

    with_collection_settings(retention: { days: 3 }) { PruneObservationsJob.perform_now }

    refute HostMetric.exists?(old_metric.id)
    assert HostMetric.exists?(recent_metric.id)
    refute Observation.exists?(old_observation.id)
    assert Observation.exists?(recent_observation.id)
  end

  test "the default keeps a week" do
    week_old, five_days = metric(8.days), metric(5.days)

    PruneObservationsJob.perform_now

    refute HostMetric.exists?(week_old.id)
    assert HostMetric.exists?(five_days.id)
  end

  test "a host's latest observation survives past the cutoff, so a long-silent host keeps its last state" do
    last_seen = observation(10.days)

    with_collection_settings(retention: { days: 3 }) { PruneObservationsJob.perform_now }

    assert Observation.exists?(last_seen.id)
  end
end
