require 'grape'
require 'project_serializer'

module Api
  class Settings < Grape::API

    #
    # Returns the current auth method
    #
    desc 'Return configurable details for the Doubtfire front end'
    get '/settings' do
      {
        externalName: Doubtfire::Application.config.institution[:product_name]
      }
    end

    desc 'Return privacy policy details'
    get '/settings/privacy' do
      {
        privacy:    Doubtfire::Application.config.institution[:privacy],
        plagiarism: Doubtfire::Application.config.institution[:plagiarism]
      }
    end
  end
end