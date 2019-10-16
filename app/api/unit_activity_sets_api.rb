require 'grape'

module Api
  class UnitActivitySetsApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc 'Add an unit activity set'
    params do
      requires :activity_type_id, type: Integer, desc: 'The id of the activity type'
    end
    post '/units/:unit_id/activity_sets' do
      unit = Unit.find(params[:unit_id])
      unless authorise? current_user, unit, :update
        error!({ error: 'Not authorised to update this unit' }, 403)
      end

      activity_type = ActivityType.find(params[:activity_type_id])
      unit.add_activity_set(activity_type)
    end

    desc 'Update an unit activity set'
    params do
      optional :activity_type_id, type: Integer, desc: 'The id of the activity type'
    end
    put '/units/:unit_id/activity_sets/:id' do
      unit = Unit.find(params[:unit_id])
      unless authorise? current_user, unit, :update
        error!({ error: 'Not authorised to update this unit' }, 403)
      end

      activity_type_id = params[:activity_type_id]
      if activity_type_id.present?
        activity_type = ActivityType.find(activity_type_id)
      end

      unit.update_activity_set(params[:id], activity_type)
    end
  end
end