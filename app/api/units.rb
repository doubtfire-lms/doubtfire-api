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

    desc "Get units"
    get '/units' do
      @units = Unit.for_user current_user
    end

    desc "Get unit"
    get '/units/:id' do
      @unit = Unit.find(params[:id])
    end

    desc "Create unit"
    post '/units' do
      unit_parameters = ActionController::Parameters.new(params)
                                          .require(:unit)
                                          .permit(
                                            :name,
                                            :code,
                                            :description,
                                            :start_date,
                                            :end_date
                                          )
      @unit = Unit.create!(unit_parameters)

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
