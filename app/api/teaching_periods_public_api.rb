require 'grape'

module Api
  class TeachingPeriodsPublicApi < Grape::API

    desc "Get a teaching period's details"
    get '/teaching_periods/:id' do
      teaching_period = TeachingPeriod.find(params[:id])
      teaching_period
    end

    desc 'Get all the Teaching Periods'
    get '/teaching_periods' do
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
