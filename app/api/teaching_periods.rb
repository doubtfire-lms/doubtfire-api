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
            unless authorise? current_user, User, :handle_teaching_period
                error!({ error: 'Not authorised to create a teaching period' }, 403)
            end

            period = params[:period]
            start_date = params[:start_date]
            end_date = params[:end_date]

            teaching_period = TeachingPeriod.new
            result = teaching_period.add_teaching_period(period, start_date, end_date)

            if result.nil?
                error!({ error: 'No teaching period added.' }, 403)
            else
                result
            end
        end
        
        desc 'Get all the Teaching Periods'
        get '/teaching_periods' do
            unless authorise? current_user, User, :get_teaching_periods
                error!({ error: 'Not authorised to get teaching periods' }, 403)
            end            
            teaching_periods = TeachingPeriod.all_teaching_periods
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