require 'grape'

class TeachingPeriodsAuthenticatedApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers

  before do
    authenticated?
  end

  desc 'Add a Teaching Period'
  params do
    requires :teaching_period, type: Hash do
      requires :period, type: String, desc: 'The name of the teaching period'
      requires :year, type: Integer, desc: 'The year of the teaching period'
      requires :start_date, type: Date, desc: 'The start date of the teaching period'
      requires :end_date, type: Date, desc: 'The end date of the teaching period'
      requires :active_until, type: Date, desc: 'The teaching period will be active until this date'
    end
  end
  post '/teaching_periods' do
    unless authorise? current_user, User, :handle_teaching_period
      error!({ error: 'Not authorised to create a teaching period' }, 403)
    end
    teaching_period_parameters = ActionController::Parameters.new(params)
                                                             .require(:teaching_period)
                                                             .permit(:period,
                                                                     :year,
                                                                     :start_date,
                                                                     :end_date,
                                                                     :active_until)

    result = TeachingPeriod.create!(teaching_period_parameters)

    if result.nil?
      error!({ error: 'No teaching period added.' }, 403)
    else
      present result, with: Entities::TeachingPeriodEntity
    end
  end

  desc 'Update teaching period'
  params do
    requires :id, type: Integer, desc: 'The teaching period id to update'
    requires :teaching_period, type: Hash do
      optional :period, type: String, desc: 'The name of the teaching period'
      optional :year, type: Integer, desc: 'The year of the teaching period'
      optional :start_date, type: Date, desc: 'The start date of the teaching period'
      optional :end_date, type: Date, desc: 'The end date of the teaching period'
      optional :active_until, type: Date, desc: 'The teaching period will be active until this date'
    end
  end
  put '/teaching_periods/:id' do
    teaching_period = TeachingPeriod.find(params[:id])
    unless authorise? current_user, User, :handle_teaching_period
      error!({ error: 'Not authorised to update a teaching period' }, 403)
    end
    teaching_period_parameters = ActionController::Parameters.new(params)
                                                             .require(:teaching_period)
                                                             .permit(:period,
                                                                     :year,
                                                                     :start_date,
                                                                     :end_date,
                                                                     :active_until)

    teaching_period.update!(teaching_period_parameters)
    teaching_period
  end

  desc 'Delete a teaching period'
  delete '/teaching_periods/:teaching_period_id' do
    unless authorise? current_user, User, :handle_teaching_period
      error!({ error: 'Not authorised to delete a teaching period' }, 403)
    end

    teaching_period_id = params[:teaching_period_id]
    TeachingPeriod.find(teaching_period_id).destroy
  end

  desc 'Rollover a Teaching Period'
  params do
    requires :new_teaching_period_id, type: Integer, desc: 'The id of the rolled over teaching period'
    optional :rollover_inactive, type: Boolean, default: false, desc: 'Are in active units included in the roll over'
    optional :search_forward, type: Boolean, default: true, desc: 'When rolling over units, ensure that latest version is rolled over to new teaching period'
  end
  post '/teaching_periods/:existing_teaching_period_id/rollover' do
    unless authorise? current_user, User, :rollover
      error!({ error: 'Not authorised to rollover a teaching period' }, 403)
    end

    new_teaching_period_id = params[:new_teaching_period_id]
    new_teaching_period = TeachingPeriod.find(new_teaching_period_id)

    existing_teaching_period = TeachingPeriod.find(params[:existing_teaching_period_id])
    error!({ error: existing_teaching_period.errors.full_messages.first }, 403) unless existing_teaching_period.rollover(new_teaching_period, params[:search_forward], params[:rollover_inactive])
  end
end
