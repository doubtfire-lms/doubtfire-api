require 'grape'

class SettingsApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers
  #
  # Returns the current auth method
  #
  desc 'Return configurable details for the Doubtfire front end'
  get '/settings' do
    # Require authentication for the main settings endpoint
    authenticated?

    begin
      response = {
        externalName: Doubtfire::Application.config.institution[:product_name],
        hasLogo: Doubtfire::Application.config.institution[:has_logo],
        logoUrl: Doubtfire::Application.config.institution[:logo_url],
        logoLinkUrl: Doubtfire::Application.config.institution[:logo_link_url],
        overseerEnabled: Doubtfire::Application.config.overseer_enabled,
        tiiEnabled: TurnItIn.enabled?,
        d2lEnabled: D2lIntegration.enabled?
      }

      present response, with: Grape::Presenters::Presenter
    rescue StandardError => e
      logger.error "Error fetching settings: #{e.message}"
      error!({ error: "Could not retrieve settings due to an internal error" }, 500)
    end
  end

  #
  # Public endpoint - safe to access without authentication
  #
  desc 'Return public application settings without authentication'
  get '/settings/public' do
    response = {
      externalName: Doubtfire::Application.config.institution[:product_name]
      # Include only non-sensitive settings here
    }

    present response, with: Grape::Presenters::Presenter
  end

  desc 'Return privacy policy details'
  get '/settings/privacy' do
    authenticated?

    response = {
      privacy: Doubtfire::Application.config.institution[:privacy],
      plagiarism: Doubtfire::Application.config.institution[:plagiarism]
    }

    present response, with: Grape::Presenters::Presenter
  end
end
