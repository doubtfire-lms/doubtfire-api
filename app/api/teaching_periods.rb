require 'grape'

module Api
    class TeachingPeriods < Grape::API
        helpers AuthenticationHelpers
        helpers AuthorisationHelpers
    
        before do
          authenticated?
        end
        
        desc 'Add a Teaching Period'
        params do
          requires :period, type: String, desc: 'The teaching period to add'
          requires :start_date, type: Date, desc: 'The start date of the teaching period'
          requires :end_date, type: Date, desc: 'The last date of the teaching period'
        end
        post '/teaching_periods' do

        end
        
        desc 'Get all the Teaching Periods'
        get '/teaching_periods' do
            teaching_periods = teaching_period.all_teaching_periods
            result = teaching_periods.map do |c|
                {
                    id: c.id,
                    period: c.period,
                    start_date: c.start_date,
                    end_date: c.end_date,                    
                }
            end
            result        
        end

    end    
end