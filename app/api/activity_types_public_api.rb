require 'grape'

class ActivityTypesPublicApi < Grape::API
  desc "Get an activity type details"
  get '/activity_types/:id' do
    present ActivityType.find(params[:id]), with: Entities::ActivityTypeEntity
  end

  desc 'Get all the activity types'
  get '/activity_types' do
    present ActivityType.all, with: Entities::ActivityTypeEntity
  end
end
