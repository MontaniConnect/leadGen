# One shared password in front of the whole app (HTTP Basic). Lead data, exports and the buttons that spend
# money must never be reachable without it. Turned on by config.x.require_access_password (production).
#
#   APP_PASSWORD   required in production. If it is missing, EVERY request is refused (fail closed).
#   APP_USERNAME   optional, defaults to "montani".
#
# The health check (/up) is served by Rails itself and is not behind the gate, so Railway can probe it.
module AccessGate
  extend ActiveSupport::Concern

  REALM = "Montani lead app".freeze

  included do
    before_action :require_access
  end

  private

  def require_access
    return unless Rails.configuration.x.require_access_password

    password = ENV["APP_PASSWORD"].to_s
    return render(plain: "Access is not configured. Set APP_PASSWORD on the server.", status: :service_unavailable) if password.empty?

    authenticate_or_request_with_http_basic(REALM) do |username, supplied|
      # Both comparisons always run, and each takes the same time however much of the guess is right.
      user_ok = ActiveSupport::SecurityUtils.secure_compare(username.to_s, ENV.fetch("APP_USERNAME", "montani"))
      password_ok = ActiveSupport::SecurityUtils.secure_compare(supplied.to_s, password)
      user_ok & password_ok
    end
  end
end
