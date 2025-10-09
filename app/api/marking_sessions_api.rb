require 'grape'

class MarkingSessionsApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers

  format :json
  prefix :api

  before do
    authenticated?
  end

  # Raw marking session data endpoints
  desc "Retrieve all marking session records for a unit"
  params do
    requires :unit_id, type: Integer, desc: "Unit ID"
    optional :start_date, type: Date, desc: "Start date for analytics"
    optional :end_date, type: Date, desc: "End date for analytics"
  end
  get '/units/:unit_id/marking_sessions' do
    unit = Unit.find(params[:unit_id])

    unless authorise?(current_user, unit, :get_tutor_times)
      error!({ error: "You are not authorised to view marking sessions for this unit" }, 403)
    end

    end_date = (params[:end_date] || Time.zone.today).end_of_day
    start_date = (params[:start_date] || (end_date - 7.days)).beginning_of_day

    sessions = MarkingSession
               .includes(:session_activities)
               .where(unit: unit)
               .where(start_time: start_date..end_date)

    present sessions, with: Entities::MarkingSessionEntity
  end
end
