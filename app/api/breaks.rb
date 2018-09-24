require 'grape'

module Api
  class Breaks < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc 'Add a new break to the teaching period'
    params do
      requires :start_date, type: Date, desc: 'The start date of the break'
      requires :number_of_weeks, type: Integer, desc: 'Break duration'
    end
    post '/teaching_periods/:teaching_period_id/breaks' do
      unless authorise? current_user, User, :handle_teaching_period
        error!({ error: 'Not authorised to create a teaching period' }, 403)
      end

      # Find the Teaching Period to add break
      teaching_period = TeachingPeriod.find(params[:teaching_period_id])

      start_date = params[:start_date]
      number_of_weeks = params[:number_of_weeks]

      teaching_period.add_break(start_date, number_of_weeks)
    end
  end
end