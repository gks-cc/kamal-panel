# GET /health: whether the panel's background work is still running (PanelHealth), for an outside
# uptime monitor. 503 when something is overdue. Not /up: kamal-proxy's deploy health check uses that,
# and a stalled job must not make a fresh deploy of the panel itself fail its check.
# Unauthenticated, so it says only which kinds of work ran when, nothing about the managed apps.
class HealthController < ActionController::API
  def show
    report = PanelHealth.report

    checks = report.checks.to_h do |check|
      [ check.name, { ok: !check.stale?, last_finished_at: check.last_at.iso8601,
                      age_seconds: check.age.to_i, threshold_seconds: check.threshold.to_i } ]
    end

    render json: { status: report.ok? ? "ok" : "stalled", checks: },
           status: report.ok? ? :ok : :service_unavailable
  end
end
