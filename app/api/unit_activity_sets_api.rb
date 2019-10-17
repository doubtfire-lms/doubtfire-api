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

    desc "Get an unit activity set details"
    get '/unit_activity_sets/:id' do
      unless authorise? current_user, User, :get_unit_activity_sets
        error!({ error: "Couldn't find UnitActivitySet with id=#{params[:id]}" }, 403)
      end
      UnitActivitySet.find(params[:id])
    end

    desc 'Get all the unit activity sets in the Unit'
    get '/units/:unit_id/unit_activity_sets' do
      unit = Unit.find(params[:unit_id])
      unless authorise? current_user, unit, :get_unit
        error!({ error: "Couldn't find Unit with id=#{params[:unit_id]}" }, 403)
      end

      unit.unit_activity_sets
    end
  end
end