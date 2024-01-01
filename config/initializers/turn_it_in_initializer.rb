require_relative '../../app/helpers/turn_it_in'
config = Doubtfire::Application.config

# Initialise TurnItIn API
TurnItIn.load_config(config)

if config.tii_enabled
  # Turn-it-in TII configuration
  require 'tca_client'

  config.logger = Rails.logger

  # Launch the tii background jobs
  unless Rails.env.test?
    # - get eula
    # - get details
    config.after_initialize do
      TurnItIn.launch_tii(with_webhooks: Rails.env.production?)
    end
  end

  if Rails.env.development?
    # Setup authorization
    TCAClient.configure do |tii_config|
      tii_config.debugging = true
    end
  end
end
