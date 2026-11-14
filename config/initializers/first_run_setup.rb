# On a panel with no users yet, print the one-time setup link at boot (FirstRunSetup), so the first
# admin can be created from the browser. Only for the server, not for every rake task or console.
Rails.application.config.after_initialize do
  next unless defined?(Rails::Server)

  FirstRunSetup.announce if FirstRunSetup.needed?
rescue StandardError => e # a hint in the log must never keep the server from starting
  Rails.logger.warn("[setup] could not check for a first admin: #{e.class}: #{e.message}")
end
