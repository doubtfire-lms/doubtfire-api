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
    optional :timezone, type: String, desc: "Requested timezone to search sessions for"
  end
  get '/units/:unit_id/marking_sessions' do
    unit = Unit.find(params[:unit_id])

    unless authorise?(current_user, unit, :get_tutor_times)
      error!({ error: "You are not authorised to view marking sessions for this unit" }, 403)
    end

    unit_role = unit.unit_role_for(current_user)
    unless unit_role
      error!({ error: "You are not authorised to view marking sessions for this unit" }, 403)
    end

    tz = Time.zone
    tz = ActiveSupport::TimeZone[params[:timezone]] if params[:timezone]

    end_date = if params[:end_date].present?
                 tz.parse(params[:end_date].to_s).end_of_day
               else
                 tz.today.end_of_day
               end

    start_date = if params[:start_date].present?
                   tz.parse(params[:start_date].to_s).beginning_of_day
                 else
                   (end_date - 7.days).beginning_of_day
                 end

    sessions = MarkingSession
               .includes(:session_activities)
               .where(unit: unit)
               .where(start_time: start_date..end_date)

    sessions = sessions.where(user_id: current_user.id) if unit_role.role != Role.convenor

    present sessions, with: Entities::MarkingSessionEntity
  end
end
