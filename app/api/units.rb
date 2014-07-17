require 'grape'

module Api
  class Units < Grape::API
    helpers AuthHelpers

    before do
      authenticated?

      if params[:unit]
        if params[:unit][:start_date].present? && params[:unit][:end_date].present?
          start_date  = DateTime.parse(params[:unit][:start_date])
          end_date    = DateTime.parse(params[:unit][:end_date])

          params[:unit][:start_date]  = start_date
          params[:unit][:end_date]    = end_date
        end
      end
    end

    desc "Get units related to the current user"
    get '/units' do
      units = Unit.for_user current_user
    end

    desc "Get a unit's details"
    get '/units/:id' do
      #TODO: authorise!
      unit = Unit.find(params[:id])
    end


    desc "Update unit"
    params do
      requires :id, type: Integer, desc: 'The unit id to update'
      optional :convenors, type: JSON, desc: 'The convenor users' 
      group :unit do
        optional :name
        optional :code
        optional :description
        optional :start_date
        optional :end_date
      end
    end
    put '/units/:id' do 
      #todo auth
      unit_parameters = ActionController::Parameters.new(params)
      .require(:unit)
      .permit(:unit_id,
              :name,
              :code,
              :description,
              :start_date, 
              :end_date
             )
      unit= Unit.find_by_id(params[:id])
      unit.update!(unit_parameters)
      unit_parameters

      convenors = params[:convenors]

      if convenors 
        unit.convenors.delete! 
        convenors.each do | u | 
          userRole = UnitRole.for_user(u)
          unit.convenors << userRole
        end 
      end 

    end 


    desc "Create unit"
    params do
      group :unit do
        requires :name
        requires :code
        requires :description
        requires :start_date
        requires :end_date
        optional :convenors, type:JSON
      end
    end
    post '/units' do
      #TODO: authorise!
      unit_parameters = ActionController::Parameters.new(params)
                                          .require(:unit)
                                          .permit(
                                            :name,
                                            :code,
                                            :description,
                                            :start_date,
                                            :end_date
                                          )
      unit = Unit.create!(unit_parameters)

      if params[:unit][:convenors]
        params[:unit][:convenors].each do |convenor|
          convenor_params = ActionController::Parameters.new(convenor)
                                          .permit(
                                            :user_id,
                                            :role_id
                                          )
          UnitRole.create!(
            { unit_id: @unit.id }.merge(convenor_params)
          )
        end
      end

      @unit
    end
  end
end
