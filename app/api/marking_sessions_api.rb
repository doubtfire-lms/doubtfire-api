require 'grape'
require_dependency 'role'

class MarkingSessionsApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers

  format :json
  prefix :api

  before do
    authenticated?
  end

  # Raw marking session data endpoints
  resource :marking_sessions do
    desc "Retrieve a specific marking session record"
    params do
      requires :id, type: Integer, desc: "MarkingSession ID"
    end
    get ':id' do
      marking_session = MarkingSession.find_by(id: params[:id])
      error!({ error: "MarkingSession not found" }, 404) unless marking_session
      error!({ error: "You are not authorized to view this marking session" }, 403) unless can_view_marking_session?(current_user, marking_session)
      present marking_session, with: Entities::MarkingSessionEntity
    end

    desc "Retrieve all marking session records for a specific tutor"
    params do
      requires :tutor_id, type: Integer, desc: "Tutor ID"
    end
    get 'tutor/:tutor_id' do
      tutor = User.find_by(id: params[:tutor_id])
      error!({ error: "Tutor not found" }, 404) unless tutor
      error!({ error: "You are not authorized to view this tutor's sessions" }, 403) unless can_view_tutor_sessions?(current_user, tutor)

      sessions = MarkingSession.includes(:unit).where(marker_id: params[:tutor_id])
      authorized = sessions.select { |s| can_view_marking_session?(current_user, s) }
      present authorized, with: Entities::MarkingSessionEntity
    end

    desc "Retrieve all marking session records for a specific student's tasks"
    params do
      requires :student_id, type: Integer, desc: "Student ID"
    end
    get 'student/:student_id' do
      student = User.find_by(id: params[:student_id])
      error!({ error: "Student not found" }, 404) unless student

      sessions = MarkingSession
        .joins(session_activities: :project)
        .where(projects: { user_id: params[:student_id] })
        .distinct
        .includes(:unit, :session_activities)

      authorized = sessions.select { |s| can_view_marking_session?(current_user, s) }
      present authorized, with: Entities::MarkingSessionEntity
    end
  end

  # Session activity endpoints
  resource :session_activities do
    desc "Retrieve a specific session activity record"
    params do
      requires :id, type: Integer, desc: "SessionActivity ID"
    end
    get ':id' do
      activity = SessionActivity.find_by(id: params[:id])
      error!({ error: "SessionActivity not found" }, 404) unless activity
      error!({ error: "You are not authorized to view this session activity" }, 403) unless can_view_marking_session?(current_user, activity.marking_session)
      present activity, with: Entities::SessionActivityEntity
    end

    desc "Retrieve all session activities for a specific tutor"
    params do
      requires :tutor_id, type: Integer, desc: "Tutor ID"
    end
    get 'tutor/:tutor_id' do
      tutor = User.find_by(id: params[:tutor_id])
      error!({ error: "Tutor not found" }, 404) unless tutor
      error!({ error: "You are not authorized to view this tutor's activities" }, 403) unless can_view_tutor_sessions?(current_user, tutor)

      activities = SessionActivity
        .joins(:marking_session)
        .where(marking_sessions: { marker_id: params[:tutor_id] })
        .includes(:marking_session, :project, :task, :task_definition)
      present activities, with: Entities::SessionActivityEntity
    end

    desc "Retrieve all session activities for a specific student"
    params do
      requires :student_id, type: Integer, desc: "Student ID"
    end
    get 'student/:student_id' do
      student = User.find_by(id: params[:student_id])
      error!({ error: "Student not found" }, 404) unless student

      activities = SessionActivity
        .joins(:project)
        .where(projects: { user_id: params[:student_id] })
        .includes(:marking_session, :project, :task, :task_definition)
      authorized = activities.select { |a| can_view_marking_session?(current_user, a.marking_session) }
      present authorized, with: Entities::SessionActivityEntity
    end
  end

  # Aggregated analytics endpoints
  resource :marking_analytics do
    desc "Get aggregated marking analytics for a specific tutor"
    params do
      requires :tutor_id, type: Integer, desc: "Tutor ID"
      optional :start_date, type: Date, desc: "Start date for analytics"
      optional :end_date, type: Date, desc: "End date for analytics"
    end
    get 'tutor/:tutor_id' do
      tutor = User.find_by(id: params[:tutor_id])
      error!({ error: "Tutor not found" }, 404) unless tutor
      error!({ error: "You are not authorized to view this tutor's analytics" }, 403) unless can_view_tutor_sessions?(current_user, tutor)

      query = MarkingSession.where(marker_id: params[:tutor_id])
      query = query.where('start_time >= ?', params[:start_date]) if params[:start_date]
      query = query.where('start_time <= ?', params[:end_date]) if params[:end_date]

      analytics = {
        total_sessions: query.count,
        total_duration_minutes: query.sum(:duration_minutes),
        avg_session_duration: query.average(:duration_minutes)&.round(2),
        total_activities: SessionActivity.joins(:marking_session).where(marking_sessions: { id: query.select(:id) }).count,
        activities_by_action: SessionActivity.joins(:marking_session).where(marking_sessions: { id: query.select(:id) }).group(:action).count
      }
      present analytics
    end

    desc "Get aggregated marking analytics for a specific unit"
    params do
      requires :unit_id, type: Integer, desc: "Unit ID"
      optional :start_date, type: Date, desc: "Start date for analytics"
      optional :end_date, type: Date, desc: "End date for analytics"
    end
    get 'unit/:unit_id' do
      unit = Unit.find_by(id: params[:unit_id])
      error!({ error: "Unit not found" }, 404) unless unit
      error!({ error: "You are not authorized to view this unit's analytics" }, 403) unless can_view_unit_analytics?(current_user, unit)

      query = MarkingSession.where(unit_id: params[:unit_id])
      query = query.where('start_time >= ?', params[:start_date]) if params[:start_date]
      query = query.where('start_time <= ?', params[:end_date]) if params[:end_date]

      analytics = {
        total_sessions: query.count,
        total_duration_minutes: query.sum(:duration_minutes),
        avg_session_duration: query.average(:duration_minutes)&.round(2),
        active_tutors: query.distinct.count(:marker_id),
        sessions_by_tutor: query.joins(:marker).group('users.first_name','users.last_name','users.id').count,
        total_activities: SessionActivity.joins(:marking_session).where(marking_sessions: { unit_id: params[:unit_id] }).count
      }
      present analytics
    end
  end

  helpers do
    def admin_user?(user)
      user.role_id == Role.admin.id
    end

    def convenor_user?(user)
      user.role_id == Role.convenor.id
    end

    def tutor_user?(user)
      user.role_id == Role.tutor.id
    end

    def can_view_marking_session?(user, session)
      return true if admin_user?(user)
      return session.marker_id == user.id if tutor_user?(user)
      return session.unit.unit_roles.exists?(user_id: user.id, role_id: Role.convenor.id) if convenor_user?(user)
      false
    end

    def can_view_tutor_sessions?(user, tutor)
      return true if admin_user?(user)
      return true if user.id == tutor.id
      if convenor_user?(user)
        (tutor.unit_roles.pluck(:unit_id) & user.unit_roles.where(role_id: Role.convenor.id).pluck(:unit_id)).any?
      else
        false
      end
    end

    def can_view_unit_analytics?(user, unit)
      return true if admin_user?(user)
      return unit.unit_roles.exists?(user_id: user.id, role_id: Role.convenor.id) if convenor_user?(user)
      false
    end
  end
end
