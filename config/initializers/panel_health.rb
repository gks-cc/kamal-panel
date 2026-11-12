# When this process started. PanelHealth counts each background-work check from here until that work
# first finishes. Kept in config rather than on the class, which code reloading would reset.
Rails.application.config.x.booted_at = Time.current
