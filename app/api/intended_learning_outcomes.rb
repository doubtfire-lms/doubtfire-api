require 'grape'

module Api
  class IntendedLearningOutcomes < Grape::API
    helpers AuthHelpers
    helpers AuthorisationHelpers
    
    before do
      authenticated?
    end

    desc "Create ILO"
    params do
      requires :unit_id           , type: Integer,  desc: 'The unit ID for which the ILO belongs to'
      requires :name              , type: String,  desc: 'The ILO''s name'
      requires :description          , type: String,   desc: 'The ILO''s description'
    end
    post '/ilos' do
      unit = Unit.find(params[:unit_id])

      # if not (authorise? current_user, unit, :add_ilo)
      #   error!({"error" => "Not authorised to create new tutorials"}, 403)
      # end

      ilo = unit.add_ilo(params[:name], params[:description])
      ilo
    end

    desc "Update ILO"
    params do
      optional :name  , type: String,   desc: 'The ILO''s new name'
      optional :description  , type: String,   desc: 'The ILO''s new description'
      optional :ilo_number, type: Integer,   desc: 'The ILO''s new sequence number'
    end
    put '/ilos/:id' do
      ilo = IntendedLearningOutcome.find(params[:id])
      unit = Unit.find(ilo.unit_id)
      
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
    delete '/ilos' do
      ilo = IntendedLearningOutcome.find(params[:ilo_id])

      # if not (authorise? current_user, unit, :add_ilo)
      #   error!({"error" => "Not authorised to create new tutorials"}, 403)
      # end

      ilo.destroy
      nil
    end

  end
end
