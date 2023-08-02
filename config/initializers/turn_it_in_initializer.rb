# Initialise TurnItIn API
# - get eula
# - get details
if Doubtfire::Application.config.tii_enabled && !Rails.env.test?
  Doubtfire::Application.config.after_initialize do
    TurnItIn.launch_tii(with_webhooks: Rails.env.production?)
  end
end
