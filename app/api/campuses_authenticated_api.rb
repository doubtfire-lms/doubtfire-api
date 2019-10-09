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
        requires :name,         type: String, desc: 'The name of the campus'
        requires :mode,         type: String, desc: 'This will determine the campus mode', values: ['timetable', 'automatic', 'manual']
        requires :abbreviation, type: String, desc: 'The abbreviation for the campus'
      end
    end
    post '/campuses' do
      unless authorise? current_user, User, :handle_campuses
        error!({ error: 'Not authorised to create a campus' }, 403)
      end
      campus_parameters = ActionController::Parameters.new(params)
                                                               .require(:campus)
                                                               .permit(:name,
                                                                      :mode,
                                                                      :abbreviation)

      result = Campus.create!(campus_parameters)

      if result.nil?
        error!({ error: 'No campus added.' }, 403)
      else
        result
      end
    end

    desc 'Update Campus'
    params do
      requires :campus, type: Hash do
        optional :name, type: String, desc: 'The name of the campus'
        optional :mode, type: String, values: ['timetable', 'automatic', 'manual'], desc: 'This will determine the campus mode'
      end
    end
    put '/campuses/:id' do
      campus = Campus.find(params[:id])
      unless authorise? current_user, User, :handle_campuses
        error!({ error: 'Not authorised to update a campus' }, 403)
      end
      campus_parameters = ActionController::Parameters.new(params)
                                                               .require(:campus)
                                                               .permit(:name,
                                                                       :mode)

      campus.update!(campus_parameters)
      campus
    end
  end
end