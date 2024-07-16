require 'grape'

class SettingsApi < Grape::API
  #
  # Returns the current auth method
  #
  desc 'Return configurable details for the Doubtfire front end'
  get '/settings' do
    response = {
      externalName: Doubtfire::Application.config.institution[:product_name],
      overseerEnabled: Doubtfire::Application.config.overseer_enabled,
      tiiEnabled: TurnItIn.enabled?
    }

    present response, with: Grape::Presenters::Presenter
  end

  desc 'Return privacy policy details'
  get '/settings/privacy' do
    response = {
      privacy: Doubtfire::Application.config.institution[:privacy],
      plagiarism: Doubtfire::Application.config.institution[:plagiarism]
    }

    present response, with: Grape::Presenters::Presenter
  end
end
