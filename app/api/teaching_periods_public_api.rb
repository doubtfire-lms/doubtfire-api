require 'grape'

class TeachingPeriodsPublicApi < Grape::API
  desc "Get a teaching period's details"
  get '/teaching_periods/:id' do
    teaching_period = TeachingPeriod.find(params[:id])
    present teaching_period, with: Entities::TeachingPeriodEntity, full_details: true, user: current_user
  end

  desc 'Get all the Teaching Periods'
  get '/teaching_periods' do
    teaching_periods = TeachingPeriod.all
    present teaching_periods, with: Entities::TeachingPeriodEntity
  end
end
