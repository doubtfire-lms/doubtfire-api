require 'grape'

module Api
  class TutorialsApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    ## --- Deprecated ---
    # Use new endpoints that use unit activity sets
    desc 'Update a tutorial'
    params do
      requires :id, type: Integer, desc: 'The user id to update'
      requires :tutorial, type: Hash do
        optional :abbreviation, type: String, desc: 'The tutorials code'
        optional :meeting_location, type: String,   desc: 'The tutorials location'
        optional :meeting_day, type: String, desc: 'Day of the tutorial'
        optional :tutor_id, type: Integer, desc: 'Id of the tutor'
        optional :campus_id, type: Integer, desc: 'Id of the campus'
        optional :capacity, type: Integer, desc: 'Capacity of the tutorial'
        optional :meeting_time, type: String, desc: 'Time of the tutorial'
      end
    end
    put '/tutorials/:id' do
      tutorial = Tutorial.find(params[:id])
      tut_params = params[:tutorial]
      # can only modify if current_user.id is same as :id provided
      # (i.e., user wants to update their own data) or if update_user token
      unless authorise? current_user, tutorial.unit, :add_tutorial
        error!({ error: "Cannot update tutorial with id=#{params[:id]} - not authorised" }, 403)
      end

      tutorial_parameters = ActionController::Parameters.new(params)
                                                        .require(:tutorial)
                                                        .permit(
                                                          :abbreviation,
                                                          :meeting_location,
                                                          :meeting_day,
                                                          :meeting_time,
                                                          :campus_id,
                                                          :capacity
                                                        )

      if tut_params[:tutor_id]
        tutor = User.find(tut_params[:tutor_id])
        tutorial.assign_tutor(tutor)
      end

      tutorial.update!(tutorial_parameters)
      tutorial
    end

    ## --- Deprecated ---
    # Use new endpoints that use unit activity sets
    desc 'Create tutorial'
    params do
      requires :tutorial, type: Hash do
        requires :unit_id,          type: Integer,  desc: 'Id of the unit'
        requires :tutor_id,         type: Integer,  desc: 'Id of the tutor'
        requires :campus_id,        type: Integer,  desc: 'Id of the campus',           allow_blank: false
        requires :capacity,         type: Integer,  desc: 'Capacity of the tutorial',   allow_blank: false
        requires :abbreviation,     type: String,   desc: 'The tutorials code',         allow_blank: false
        requires :meeting_location, type: String,   desc: 'The tutorials location',     allow_blank: false
        requires :meeting_day,      type: String,   desc: 'Day of the tutorial',        allow_blank: false
        requires :meeting_time,     type: String,   desc: 'Time of the tutorial',       allow_blank: false
      end
    end
    post '/tutorials' do
      tut_params = params[:tutorial]
      unit = Unit.find(tut_params[:unit_id])

      unless authorise? current_user, unit, :add_tutorial
        error!({ error: 'Not authorised to create new tutorials' }, 403)
      end

      tutor = User.find(tut_params[:tutor_id])
      campus = Campus.find(tut_params[:campus_id])

      tutorial = unit.add_tutorial(tut_params[:meeting_day], tut_params[:meeting_time], tut_params[:meeting_location], tutor, campus, tut_params[:capacity], tut_params[:abbreviation])
      tutorial
    end

    ## --- Deprecated ---
    # Use new endpoints that use unit activity sets
    desc 'Delete a tutorial'
    params do
      requires :id, type: Integer, desc: 'The tutorial id to delete'
    end
    delete '/tutorials/:id' do
      tutorial = Tutorial.find(params[:id])

      unless authorise? current_user, tutorial.unit, :add_tutorial
        error!({ error: 'Cannot delete tutorial - not authorised' }, 403)
      end

      tutorial.destroy!
      tutorial
    end

    # New tutorial endpoints to incorporate unit activity sets
    # These will eventually replace old endpoints
    desc 'Create tutorial'
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
  end
end
