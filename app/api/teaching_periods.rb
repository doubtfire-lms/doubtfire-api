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
      requires :period, type: String, desc: 'The teaching period to add', allow_blank: false
      requires :start_date, type: Date, desc: 'The start date of the teaching period', allow_blank: false
      requires :end_date, type: Date, desc: 'The last date of the teaching period', allow_blank: false
    end
    post '/teaching_periods' do
      unless authorise? current_user, User, :handle_teaching_period
        error!({ error: 'Not authorised to create a teaching period' }, 403)
      end

      period = params[:period]
      start_date = params[:start_date]
      end_date = params[:end_date]

      if end_date > start_date
        result = TeachingPeriod.create!(period: period, start_date: start_date, end_date: end_date)                 
      else
        error!({ error: 'End date should be after the start date' }, 403)        
      end

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
      teaching_periods = TeachingPeriod.all
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

    desc 'Delete a teaching period'
    delete '/teaching_periods/:teaching_period_id' do
      unless authorise? current_user, User, :handle_teaching_period
        error!({ error: 'Not authorised to delete a teaching period' }, 403)
      end

      teaching_period_id = params[:teaching_period_id]
      TeachingPeriod.find(teaching_period_id).destroy            
    end
  end    
end