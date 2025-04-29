# Be sure to restart your server when you modify this file.

# Configuration for authentication session security
Doubtfire::Application.config.session_security = {
  binding_enabled: true,               # Enable/disable session binding completely
  ip_binding_strictness: :flexible,    # :strict, :flexible, or :disabled
  max_allowed_ip_changes: 3,           # Maximum number of different IPs allowed per token
  suspicious_change_timeout: 5.minutes, # Period to allow suspicious changes before requiring re-auth
  token_max_lifetime: 8.hours,         # Maximum lifetime of a token, regardless of activity
  auth_enforcement_window: 15.seconds  # Time window to check for forced session persistence
}
Rails.logger.info "Loading session security config at #{Time.zone.now}"
