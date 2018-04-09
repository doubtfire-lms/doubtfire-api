require 'grape'

module Api
    class TeachingPeriods < Grape::API
        helpers AuthenticationHelpers
        helpers AuthorisationHelpers
    
        before do
          authenticated?
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