require 'grape'

module Api
  class LearningOutcomes < Grape::API
    helpers AuthHelpers
    helpers AuthorisationHelpers
    
    before do
      authenticated?
    end

    desc "Add an outcome to a unit"
    params do
      requires :unit_id           , type: Integer,  desc: 'The unit ID for which the ILO belongs to'
      requires :name              , type: String,   desc: 'The ILO''s name'
      requires :description       , type: String,   desc: 'The ILO''s description'
    end
    post '/units/:unit_id/outcomes' do
      unit = Unit.find(params[:unit_id])

      if not (authorise? current_user, unit, :update)
        error!({"error" => "You are not authorised to create outcomes in this unit."}, 403)
      end

      ilo = unit.add_ilo(params[:name], params[:description])
      ilo
    end

    desc "Update ILO"
    params do
      requires :unit_id       , type: Integer,  desc: 'The unit ID for which the ILO belongs to'
      optional :name          , type: String,   desc: 'The ILO''s new name'
      optional :description   , type: String,   desc: 'The ILO''s new description'
      optional :ilo_number    , type: Integer,  desc: 'The ILO''s new sequence number'
    end
    put '/units/:unit_id/outcomes/:id' do
      unit = Unit.find(params[:unit_id])
      error!({"error" => "Unable to locate requested unit."}, 405) if unit.nil?

      if not (authorise? current_user, unit, :update)
        error!({"error" => "You are not authorised to update outcomes in this unit."}, 403)
      end

      ilo = unit.learning_outcomes.find(params[:id])
      error!({"error" => "Unable to locate outcome requested."}, 405) if ilo.nil?
      
      ilo_parameters = ActionController::Parameters.new(params)
                                          .permit(
                                            :name,
                                            :description
                                          )
      if params[:ilo_number]
        unit.move_ilo(ilo, params[:ilo_number])
      end                                  
      ilo.update!(ilo_parameters)
      ilo
    end

    desc "Delete ILO"
    params do
      requires :ilo_id           , type: Integer,  desc: 'The ILO ID for the ILO you wish to delete'
    end
    delete '/units/:unit_id/outcomes/:id' do
      unit = Unit.find(params[:unit_id])
      error!({"error" => "Unable to locate requested unit."}, 405) if unit.nil?

      if not (authorise? current_user, unit, :update)
        error!({"error" => "You are not authorised to delete outcomes in this unit."}, 403)
      end

      ilo = unit.learning_outcomes.find(params[:id])
      error!({"error" => "Unable to locate outcome requested."}, 405) if ilo.nil?

      ilo.destroy
      nil
    end

  end
end
