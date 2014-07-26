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
      group :tutorial do
        optional :abbreviation  , type: String,   desc: 'The tutorials code'
        optional :location      , type: String,   desc: 'The tutorials location'
        optional :day           , type: String,   desc: 'Day of the tutorial'
        optional :tutor_id      , type: Integer,  desc: 'Id of the tutor'
      end
    end
    put '/tutorials/:id' do
      tutorial = Tutorial.find(params[:id])
      tut_params = params[:tutorial]
      # can only modify if current_user.id is same as :id provided
      # (i.e., user wants to update their own data) or if updateUser token
      if not authorise? current_user, tutorial.unit, :add_tutorial
        error!({"error" => "Cannot update tutorial with id=#{params[:id]} - not authorised" }, 403)
      end

      tutorial_parameters = ActionController::Parameters.new(params)
                                          .require(:tutorial)
                                          .permit(
                                            :abbreviation,
                                            :location,
                                            :day
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
      group :tutorial do
        requires :unit_id       , type: Integer,  desc: 'Id of the unit'
        requires :tutor_id      , type: Integer,  desc: 'Id of the tutor'
        requires :abbreviation  , type: String,   desc: 'The tutorials code'
        requires :location      , type: String,   desc: 'The tutorials location'
        requires :day           , type: String,   desc: 'Day of the tutorial'
      end
    end
    post '/tutorials' do
      tut_params = params[:tutorial]
      unit = Unit.find(tut_params[:unit_id])

      if not (authorise? current_user, unit, :add_tutorial)
        error!({"error" => "Not authorised to create new tutorials"}, 403)
      end

      tutor = User.find(tut_params[:tutor_id])

      tutorial = unit.add_tutorial( tut_params[:day], tut_params[:time], tut_params[:location], tutor, tut_params[:abbreviation] )
      tutorial
    end
  end
end
