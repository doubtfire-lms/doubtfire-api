require 'grape'

module D2lIntegrationApi
  # Public api for oauth callback
  class OauthPublicApi < Grape::API
    include LogHelper

    desc 'Callback for oauth login'
    params do
      requires :code, type: String, desc: 'The code returned from the OAuth login'
      requires :state, type: String, desc: 'The state returned from the OAuth login'
    end
    get '/d2l/callback' do
      D2lIntegration.process_callback(params[:code], params[:state])

      host = Doubtfire::Application.config.institution[:host]
      redirect "#{host}/success-close"
    rescue StandardError => e
      error!({ error: "Error processing oauth callback: #{e.message}" }, 500)
    end
  end
end
