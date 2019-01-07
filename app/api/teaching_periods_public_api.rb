require 'grape'

module Api
  class TeachingPeriodsPublicApi < Grape::API

    desc "Get a teaching period's details"
    get '/teaching_periods/:id' do
      teaching_period = TeachingPeriod.find(params[:id])
      teaching_period
    end

    desc 'Get all the Teaching Periods'
    params do
      optional :auth_token, type: String, desc: 'Authentication token'
    end
    get '/teaching_periods' do
      unless authorise? current_user, User, :get_teaching_periods
        error!({ error: 'Not authorised to get teaching periods' }, 403)
      end
      teaching_periods = TeachingPeriod.all
      result = teaching_periods.map do |c|
        {
          id: c.id,
          period: c.period,
          year: c.year,
          start_date: c.start_date,
          end_date: c.end_date,
          active_until: c.active_until
        }
      end
      result
    end
  end
end
