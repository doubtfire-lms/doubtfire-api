require_relative '../../app/helpers/d2l_integration'
config = Doubtfire::Application.config

# Initialise TurnItIn API
D2lIntegration.load_config(config)
