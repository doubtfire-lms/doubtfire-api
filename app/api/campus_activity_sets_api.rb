require 'grape'

module Api
  class CampusActivitySetsApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc 'Add a campus activity set'
    params do
      requires :unit_activity_set_id, type: Integer, desc: 'The id of the unit activity set'
    end
    post '/campuses/:campus_id/activity_sets' do
      unless authorise? current_user, User, :handle_campus_activity_sets
        error!({ error: 'Not authorised to create a campus activity set' }, 403)
      end

      unit_activity_set = UnitActivitySet.find(params[:unit_activity_set_id])
      campus = Campus.find(params[:campus_id])
      campus.add_activity_set(unit_activity_set)
    end

    desc 'Update a campus activity set'
    params do
      optional :unit_activity_set_id, type: Integer, desc: 'The id of the unit activity set'
    end
    put '/campuses/:campus_id/activity_sets/:id' do
      unless authorise? current_user, User, :handle_campus_activity_sets
        error!({ error: 'Not authorised to update a campus activity set' }, 403)
      end

      unit_activity_set_id = params[:unit_activity_set_id]
      if unit_activity_set_id.present?
        unit_activity_set = UnitActivitySet.find(unit_activity_set_id)
      end

      campus = Campus.find(params[:campus_id])
      campus.update_activity_set(params[:id], unit_activity_set)
    end
  end
end