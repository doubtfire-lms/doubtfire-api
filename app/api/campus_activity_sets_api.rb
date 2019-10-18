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
      unit_activity_set = UnitActivitySet.find(params[:unit_activity_set_id])
      unit = unit_activity_set.unit
      unless authorise? current_user, unit, :update
        error!({ error: 'Not authorised to update this unit' }, 403)
      end

      campus = Campus.find(params[:campus_id])
      campus.add_activity_set(unit_activity_set)
    end
  end
end