require 'grape'

module Api
  class Units < Grape::API
    helpers AuthHelpers

    before do
      authenticated?
    end

    desc "Get units"
    get '/units' do
      @units = Unit.for_user current_user
    end

    desc "Get unit"
    get '/units/:id' do
      @unit = Unit.find(params[:id])
    end
  end
end
