require 'grape'

module Api
  class CampusesAuthenticatedApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc 'Add a Campus'
    params do
      requires :campus, type: Hash do
        requires :name, type: String, desc: 'The name of the campus'
        requires :mode, type: String, desc: 'This will determine the campus mode'
      end
    end
    post '/campus' do
      unless authorise? current_user, User, :handle_campuses
        error!({ error: 'Not authorised to create a campus' }, 403)
      end
      campus_parameters = ActionController::Parameters.new(params)
                                                               .require(:campus)
                                                               .permit(:name,
                                                                       :mode)

      result = Campus.create!(campus_parameters)

      if result.nil?
        error!({ error: 'No campus added.' }, 403)
      else
        result
      end
    end
  end
end