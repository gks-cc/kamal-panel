# Creating the first admin from the browser, on a panel that has no users yet.
#
# Whoever reaches a fresh panel first must not become its admin just by getting there first (it is
# often on a public address before anyone signs in). So the setup page asks for a one-time token
# that only someone who can read the panel's logs has: it is printed at boot and every time the
# setup page is opened without it, and it stops working once the first user exists.
module FirstRunSetup
  TOKEN_KEY = "first_run_setup/token".freeze

  module_function

  def needed? = !User.exists?

  def token = Rails.cache.fetch(TOKEN_KEY) { SecureRandom.urlsafe_base64(24) }

  def valid_token?(given)
    given.present? && ActiveSupport::SecurityUtils.secure_compare(given.to_s, token)
  end

  def link
    # Spelled out rather than setup_path: this runs at boot, before the routes are loaded.
    path = "/setup?#{{ token: }.to_query}"
    PanelUrl.for(path) || "<panel address>#{path}"
  end

  def announce(logger: Rails.logger)
    logger.warn("[setup] No users yet. Create the first admin at: #{link}")
  end

  # Creates the admin unless someone else finished first; nil then.
  def create_admin(attributes)
    User.transaction do
      return nil unless needed?

      user = User.new(attributes.merge(role: "admin"))
      next user unless user.save

      AuditLog.record_access!(user:, action_name: "user.create", target_user: user, detail_key: "user.first_admin")
      Rails.cache.delete(TOKEN_KEY)
      user
    end
  end
end
