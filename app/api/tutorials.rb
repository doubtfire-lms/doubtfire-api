require 'grape'

module Api
  class Tutorials < Grape::API
    helpers AuthHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc "Update a tutorial"
    params do
      requires :id, type: Integer, desc: 'The user id to update'
      requires :tutorial, type: Hash do
        optional :abbreviation  , type: String,   desc: 'The tutorials code'
        optional :meeting_location      , type: String,   desc: 'The tutorials location'
        optional :meeting_day           , type: String,   desc: 'Day of the tutorial'
        optional :tutor_id              , type: Integer,  desc: 'Id of the tutor'
        optional :meeting_time          , type: String,   desc: 'Time of the tutorial'
      end
    end
    put '/tutorials/:id' do
      tutorial = Tutorial.find(params[:id])
      tut_params = params[:tutorial]
      # can only modify if current_user.id is same as :id provided
      # (i.e., user wants to update their own data) or if update_user token
      if not authorise? current_user, tutorial.unit, :add_tutorial
        error!({"error" => "Cannot update tutorial with id=#{params[:id]} - not authorised" }, 403)
      end

      tutorial_parameters = ActionController::Parameters.new(params)
                                          .require(:tutorial)
                                          .permit(
                                            :abbreviation,
                                            :meeting_location,
                                            :meeting_day,
                                            :meeting_time
                                          )

      if tut_params[:tutor_id]
        tutor = User.find(tut_params[:tutor_id])
        tutorial.assign_tutor(tutor)
      end

      tutorial.update!(tutorial_parameters)
      tutorial
    end

    desc "Create tutorial"
    params do
      requires :tutorial, type: Hash do
        requires :unit_id               , type: Integer,  desc: 'Id of the unit'
        requires :tutor_id              , type: Integer,  desc: 'Id of the tutor'
        requires :abbreviation          , type: String,   desc: 'The tutorials code'
        requires :meeting_location      , type: String,   desc: 'The tutorials location'
        requires :meeting_day           , type: String,   desc: 'Day of the tutorial'
        requires :meeting_time          , type: String,   desc: 'Time of the tutorial'
      end
    end
    post '/tutorials' do
      tut_params = params[:tutorial]
      unit = Unit.find(tut_params[:unit_id])

      if not (authorise? current_user, unit, :add_tutorial)
        error!({"error" => "Not authorised to create new tutorials"}, 403)
      end

      tutor = User.find(tut_params[:tutor_id])

      tutorial = unit.add_tutorial( tut_params[:meeting_day], tut_params[:meeting_time], tut_params[:meeting_location], tutor, tut_params[:abbreviation] )
      tutorial
    end

    desc "Delete a tutorial"
    params do
      requires :id, type: Integer, desc: 'The tutorial id to delete'
    end
    delete '/tutorials/:id' do
      tutorial = Tutorial.find(params[:id])

      if not authorise? current_user, tutorial.unit, :add_tutorial
        error!({"error" => "Cannot delete tutorial - not authorised" }, 403)
      end

      tutorial.destroy!
      tutorial
    end
  end
end
