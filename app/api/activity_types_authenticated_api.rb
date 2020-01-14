require 'grape'

module Api
  class ActivityTypesAuthenticatedApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc 'Add an activity type'
    params do
      requires :activity_type, type: Hash do
        requires :name,         type: String,  desc: 'The name of the activity type'
        requires :abbreviation, type: String,  desc: 'The abbreviation for the activity type'
      end
    end
    post '/activity_types' do
      unless authorise? current_user, User, :handle_activity_types
        error!({ error: 'Not authorised to create an activity type' }, 403)
      end
      activity_type_parameters = ActionController::Parameters.new(params)
                                                               .require(:activity_type)
                                                               .permit(:name,
                                                                      :abbreviation)

      result = ActivityType.create!(activity_type_parameters)

      if result.nil?
        error!({ error: 'No activity type added' }, 403)
      else
        result
      end
    end

    desc 'Update an activity type'
    params do
      requires :activity_type, type: Hash do
        optional :name,         type: String,  desc: 'The name of the activity type'
        optional :abbreviation, type: String,  desc: 'The abbreviation for the activity type'
      end
    end
    put '/activity_types/:id' do
      activity_type = ActivityType.find(params[:id])
      unless authorise? current_user, User, :handle_activity_types
        error!({ error: 'Not authorised to update an activity type' }, 403)
      end
      activity_type_parameters = ActionController::Parameters.new(params)
                                                               .require(:activity_type)
                                                               .permit(:name,
                                                                      :abbreviation)

      activity_type.update!(activity_type_parameters)
      activity_type
    end

    desc 'Delete an activity type'
    delete '/activity_types/:id' do
      unless authorise? current_user, User, :handle_activity_types
        error!({ error: 'Not authorised to delete an activity type' }, 403)
      end

      activity_type = ActivityType.find(params[:id])
      activity_type.destroy
      error!({ error: activity_type.errors.full_messages.last }, 403) unless activity_type.destroyed?
      activity_type.destroyed?
    end
  end
end