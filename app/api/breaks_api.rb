require 'grape'

module Api
  class BreaksApi < Grape::API
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
        error!({ error: 'Not authorised to add a break' }, 403)
      end

      # Find the Teaching Period to add break
      teaching_period = TeachingPeriod.find(params[:teaching_period_id])

      start_date = params[:start_date]
      number_of_weeks = params[:number_of_weeks]

      teaching_period.add_break(start_date, number_of_weeks)
    end

    desc 'Update a break in the teaching period'
    params do
      optional :start_date, type: Date, desc: 'The start date of the break'
      optional :number_of_weeks, type: Integer, desc: 'Break duration'
    end
    put '/teaching_periods/:teaching_period_id/breaks/:id' do
      unless authorise? current_user, User, :handle_teaching_period
        error!({ error: 'Not authorised to update a break' }, 403)
      end

      # Find the Teaching Period to update break
      teaching_period = TeachingPeriod.find(params[:teaching_period_id])

      id = params[:id]
      start_date = params[:start_date]
      number_of_weeks = params[:number_of_weeks]

      teaching_period.update_break(id, start_date, number_of_weeks)
    end

    desc 'Get all the breaks in the Teaching Period'
    get '/teaching_periods/:teaching_period_id/breaks' do
      unless authorise? current_user, User, :get_teaching_periods
        error!({ error: 'Not authorised to get breaks' }, 403)
      end

      teaching_period = TeachingPeriod.find(params[:teaching_period_id])
      teaching_period.breaks
    end

    desc "Get a break's details"
    get '/breaks/:id' do
      break_details = Break.find(params[:id])
      unless authorise? current_user, User, :get_teaching_periods
        error!({ error: "Couldn't find Break with id=#{params[:id]}" }, 403)
      end
      break_details
    end

    desc 'Get all the breaks'
    get '/breaks' do
      unless authorise? current_user, User, :get_teaching_periods
        error!({ error: 'Not authorised to get breaks' }, 403)
      end
      result = Break.all
      result
    end

    desc 'Delete a break'
    delete '/breaks/:id' do
      unless authorise? current_user, User, :handle_teaching_period
        error!({ error: 'Not authorised to delete a break' }, 403)
      end

      break_id = params[:id]
      Break.find(break_id).destroy
    end
  end
end
