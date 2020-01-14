require 'grape'

module Api
  class ActivityTypesPublicApi < Grape::API

    desc "Get an activity type details"
    get '/activity_types/:id' do
      ActivityType.find(params[:id])
    end

    desc 'Get all the activity types'
    get '/activity_types' do
      ActivityType.all
    end
  end
end