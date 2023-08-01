require_relative '../../app/models/application_record'
require_relative '../../app/models/turn_it_in/tii_action'
require_relative '../../app/models/turn_it_in/tii_action_fetch_features_enabled'
require_relative '../../app/models/turn_it_in/tii_action_fetch_eula'

TurnItIn.launch_tii(with_webhooks: Rails.env.production?) if Doubtfire::Application.config.tii_enabled && !Rails.env.test?
