# Whether the panel's own background work is still running. The pages only show what the jobs last
# wrote, so when collection stops (a stuck worker thread, a dead scheduler, a locked database) the
# panel keeps showing the last good state and nothing looks wrong. Each kind of work records when a
# run last finished; one that hasn't for a few of its own cadences is reported as stalled, on every
# page (the layout's banner) and at /health for an outside monitor.
#
#   PanelHealth.beat!(:status_poll)   # at the end of a run
#   PanelHealth.report.ok?            # => false when something applicable is overdue
class PanelHealth
  Check = Data.define(:name, :last_at, :threshold, :now) do
    def age = (now - last_at).seconds
    def stale? = age > threshold
  end

  Report = Data.define(:checks) do
    def ok? = stalled.empty?
    def stalled = checks.select(&:stale?)
  end

  # name => [minimum threshold, cadence it runs at, whether it is expected to run at all]
  CHECKS = {
    status_poll: -> { [ 3.minutes, CollectionSettings.current.status_idle * 3, ManagedApp.active.exists? ] },
    metrics: -> { [ 5.minutes, 0, ManagedApp.active.where.not(ssh_credential_id: nil).where(last_poll_error: nil).exists? ] },
    alerts: -> { [ 3.minutes, CollectionSettings.current.alerts_every * 3, true ] }
  }.freeze

  class << self
    # When this process started (config/initializers/panel_health.rb). A check that has never
    # finished, or last finished before then, counts from here: a restart gets a fresh grace period
    # instead of being reported stalled by a beat from the previous run.
    def booted_at = Rails.application.config.x.booted_at
    def booted_at=(time)
      Rails.application.config.x.booted_at = time
    end

    def beat!(name, at: Time.current)
      raise ArgumentError, "unknown health check: #{name}" unless CHECKS.key?(name)

      Rails.cache.write(key(name), at)
    rescue ArgumentError
      raise
    rescue StandardError => e
      Rails.logger.warn("[health] could not record #{name}: #{e.class}: #{e.message}")
    end

    def report(now: Time.current)
      checks = CHECKS.filter_map do |name, spec|
        floor, cadence, applicable = spec.call
        next unless applicable

        last = [ Rails.cache.read(key(name)), booted_at || now ].compact.max
        Check.new(name:, last_at: last, threshold: [ floor, cadence ].max, now:)
      end
      Report.new(checks:)
    end

    private
      def key(name) = "panel_health/#{name}"
  end
end
