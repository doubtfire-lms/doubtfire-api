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
        requires :name,         type: String,  desc: 'The name of the campus'
        requires :mode,         type: String,  desc: 'This will determine the campus mode', values: ['timetable', 'automatic', 'manual']
        requires :abbreviation, type: String,  desc: 'The abbreviation for the campus'
        requires :active,       type: Boolean, desc: 'Determines whether campus is active'
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
                                                                      :abbreviation,
                                                                      :active)

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
        optional :name,         type: String,  desc: 'The name of the campus'
        optional :mode,         type: String,  desc: 'This will determine the campus mode', values: ['timetable', 'automatic', 'manual']
        optional :abbreviation, type: String,  desc: 'The abbreviation for the campus'
        optional :active,       type: Boolean, desc: 'Determines whether campus is active'
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
                                                                      :mode,
                                                                      :abbreviation,
                                                                      :active)

      campus.update!(campus_parameters)
      campus
    end

    desc 'Delete a campus'
    delete '/campuses/:id' do
      unless authorise? current_user, User, :handle_campuses
        error!({ error: 'Not authorised to delete a campus' }, 403)
      end

      campus = Campus.find(params[:id])
      campus.destroy
      error!({ error: campus.errors.full_messages.last }, 403) unless campus.destroyed?
      campus.destroyed?
    end
  end
end