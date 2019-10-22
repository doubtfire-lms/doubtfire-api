require 'grape'

module Api
  class TutorialsApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc 'Add tutorial to a unit activity set'
    params do
      requires :tutorial, type: Hash do
        requires :tutor_id,         type: Integer,  desc: 'Id of the tutor'
        requires :campus_id,        type: Integer,  desc: 'Id of the campus',           allow_blank: false
        requires :capacity,         type: Integer,  desc: 'Capacity of the tutorial',   allow_blank: false
        requires :abbreviation,     type: String,   desc: 'The tutorials code',         allow_blank: false
        requires :meeting_location, type: String,   desc: 'The tutorials location',     allow_blank: false
        requires :meeting_day,      type: String,   desc: 'Day of the tutorial',        allow_blank: false
        requires :meeting_time,     type: String,   desc: 'Time of the tutorial',       allow_blank: false
      end
    end
    post '/unit_activity_sets/:unit_activity_set_id/tutorials' do
      unit_activity_set = UnitActivitySet.find(params[:unit_activity_set_id])
      tut_params = params[:tutorial]

      unless authorise? current_user, unit_activity_set.unit, :add_tutorial
        error!({ error: 'Not authorised to create new tutorials' }, 403)
      end

      tutor = User.find(tut_params[:tutor_id])
      campus = Campus.find(tut_params[:campus_id])

      unit_activity_set.add_tutorial(tut_params[:meeting_day], tut_params[:meeting_time], tut_params[:meeting_location], tutor, campus, tut_params[:capacity], tut_params[:abbreviation])
    end

    desc 'Update a tutorial inside the unit activity set'
    params do
      requires :tutorial, type: Hash do
        optional :abbreviation,     type: String,  allow_blank: false, desc: 'The tutorials code'
        optional :meeting_location, type: String,  allow_blank: false, desc: 'The tutorials location'
        optional :meeting_day,      type: String,  allow_blank: false, desc: 'Day of the tutorial'
        optional :tutor_id,         type: Integer, allow_blank: false, desc: 'Id of the tutor'
        optional :campus_id,        type: Integer, allow_blank: false, desc: 'Id of the campus'
        optional :capacity,         type: Integer, allow_blank: false, desc: 'Capacity of the tutorial'
        optional :meeting_time,     type: String,  allow_blank: false, desc: 'Time of the tutorial'
      end
    end
    put '/unit_activity_sets/:unit_activity_set_id/tutorials/:id' do
      unit_activity_set = UnitActivitySet.find(params[:unit_activity_set_id])
      tut_params = params[:tutorial]
      unless authorise? current_user, unit_activity_set.unit, :add_tutorial
        error!({ error: "Cannot update tutorial with id=#{params[:id]} - not authorised" }, 403)
      end

      tutor_id = tut_params[:tutor_id]
      if tutor_id.present?
        tutor = User.find(tut_params[:tutor_id])
      end

      campus_id = tut_params[:campus_id]
      if campus_id.present?
        campus = Campus.find(campus_id)
      end

      unit_activity_set.update_tutorial(params[:id], tut_params[:meeting_day], tut_params[:meeting_time], tut_params[:meeting_location], tutor, campus, tut_params[:capacity], tut_params[:abbreviation])
    end

    desc 'Delete a tutorial inside the unit activity set'
    delete '/unit_activity_sets/:unit_activity_set_id/tutorials/:id' do
      unit_activity_set = UnitActivitySet.find(params[:unit_activity_set_id])
      unless authorise? current_user, unit_activity_set.unit, :add_tutorial
        error!({ error: 'Cannot delete tutorial - not authorised' }, 403)
      end

      unit_activity_set.tutorials.find(params[:id]).destroy
    end
  end
end
