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
    # desc "Retrieve a specific marking session record"
    # params do
    #   requires :id, type: Integer, desc: "MarkingSession ID"
    # end
    # get ':id' do
    #   marking_session = MarkingSession.find_by(id: params[:id])
    #   error!({ error: "MarkingSession not found" }, 404) unless marking_session
    #   error!({ error: "You are not authorized to view this marking session" }, 403) unless can_view_marking_session?(current_user, marking_session)
    #   present marking_session, with: Entities::MarkingSessionEntity
    # end

    # desc "Retrieve all marking session records for a specific tutor"
    # params do
    #   requires :user_id, type: Integer, desc: "Tutor ID"
    #   requires :unit_id, type: Integer, desc: "Unit ID"
    #   requires
    # end
    # get 'units/:unit_id/tutor/:user_id' do
    #   user = User.find(params[:user_id])
    #   unit = Unit.find(params[:unit_id])
    #   # error!({ error: "Tutor not found" }, 404) unless tutor
    #   error!({ error: "You are not authorized to view this tutor's sessions" }, 403) unless can_view_tutor_sessions?(current_user, user)

    #   # sessions = MarkingSession.where(user: user, unit: unit)
    #   # sessions = MarkingSession.includes(:session_activities).where(user: user, unit: unit)
    #   sessions = MarkingSession.includes(:session_activities).where(unit: unit)

    #   authorized = sessions.select { |s| can_view_marking_session?(current_user, s) }
    #   present authorized, with: Entities::MarkingSessionEntity
    # end

    desc "Retrieve all marking session records for a unit"
    params do
      requires :unit_id, type: Integer, desc: "Unit ID"
      optional :start_date, type: Date, desc: "Start date for analytics"
      optional :end_date, type: Date, desc: "End date for analytics"
    end
    get 'units/:unit_id' do
      unit = Unit.find(params[:unit_id])
      # error!({ error: "Tutor not found" }, 404) unless tutor
      error!({ error: "You are not authorized to view this tutor's sessions" }, 403) unless authorise?(current_user, User, :convene_units)

      sessions = MarkingSession
                 .includes(:session_activities)
                 .where(unit: unit)
                 .where('start_time >= ?', params[:start_date])
                 .where('end_time <= ?', params[:end_date])
      # query = MarkingSession.where(unit_id: id)
      # query = query.where('start_time >= ?', start_date) if start_date
      # query = query.where('start_time <= ?', end_date) if end_date

      authorized = sessions.select { |s| can_view_marking_session?(current_user, s) }
      present authorized, with: Entities::MarkingSessionEntity
    end

    # desc "Retrieve all marking session records for a specific student's tasks"
    # params do
    #   requires :student_id, type: Integer, desc: "Student ID"
    # end
    # get 'student/:student_id' do
    #   student = User.find_by(id: params[:student_id])
    #   error!({ error: "Student not found" }, 404) unless student

    #   sessions = MarkingSession
    #              .joins(session_activities: :project)
    #              .where(projects: { user_id: params[:student_id] })
    #              .distinct
    #              .includes(:unit, :session_activities)

    #   authorized = sessions.select { |s| can_view_marking_session?(current_user, s) }
    #   present authorized, with: Entities::MarkingSessionEntity
    # end
  end

  # Session activity endpoints
  resource :session_activities do
    # desc "Retrieve a specific session activity record"
    # params do
    #   requires :id, type: Integer, desc: "SessionActivity ID"
    # end
    # get ':id' do
    #   activity = SessionActivity.find_by(id: params[:id])
    #   error!({ error: "SessionActivity not found" }, 404) unless activity
    #   error!({ error: "You are not authorized to view this session activity" }, 403) unless can_view_marking_session?(current_user, activity.marking_session)
    #   present activity, with: Entities::SessionActivityEntity
    # end

    # desc "Retrieve all session activities for a specific tutor"
    # params do
    #   requires :tutor_id, type: Integer, desc: "Tutor ID"
    #   requires :unit_id, type: Integer, desc: "Unit ID"
    # end
    # get 'unit/:unit_id/tutor/:user_id' do
    #   user = User.find_by(id: params[:user_id])
    #   unit = Unit.find_by(id: params[:unit_id])

    #   # TODO: authorisation for current_user and unit

    #   # error!({ error: "Tutor not found" }, 404) unless user
    #   error!({ error: "You are not authorized to view this tutor's activities" }, 403) unless can_view_tutor_sessions?(current_user, user)

    #   activities = SessionActivity
    #                .joins(:marking_session)
    #                .where(marking_sessions: { user: user, unit: unit })
    #                .includes(:marking_session, :project, :task, :task_definition)
    #   present activities, with: Entities::SessionActivityEntity
    # end

    # desc "Retrieve all session activities for a specific student"
    # params do
    #   requires :student_id, type: Integer, desc: "Student ID"
    # end
    # get 'student/:student_id' do
    #   student = User.find_by(id: params[:student_id])
    #   error!({ error: "Student not found" }, 404) unless student

    #   activities = SessionActivity
    #                .joins(:project)
    #                .where(projects: { user_id: params[:student_id] })
    #                .includes(:marking_session, :project, :task, :task_definition)
    #   authorized = activities.select { |a| can_view_marking_session?(current_user, a.marking_session) }
    #   present authorized, with: Entities::SessionActivityEntity
    # end
  end

  # Aggregated analytics endpoints
  resource :marking_analytics do
    # desc "Get aggregated marking analytics for a specific tutor"
    # params do
    #   requires :tutor_id, type: Integer, desc: "Tutor ID"
    #   requires :unit_id, type: Integer, desc: "Unit ID"
    #   optional :start_date, type: Date, desc: "Start date for analytics"
    #   optional :end_date, type: Date, desc: "End date for analytics"
    # end
    # get 'unit/:unit_id/tutor/:tutor_id' do
    #   user = User.find(params[:tutor_id])
    #   unit = Unit.find(params[:unit_id])

    #   error!({ error: "You are not authorized to view this tutor's analytics" }, 403) unless can_view_tutor_sessions?(current_user, user)

    #   analytics = user.get_marking_analytics(unit, start_date: params[:start_date], end_date: params[:end_date])
    #   present analytics
    # end

    # desc "Get aggregated marking analytics for a specific unit"
    # params do
    #   requires :unit_id, type: Integer, desc: "Unit ID"
    #   optional :start_date, type: Date, desc: "Start date for analytics"
    #   optional :end_date, type: Date, desc: "End date for analytics"
    # end
    # get 'unit/:unit_id' do
    #   unit = Unit.find_by(id: params[:unit_id])

    #   error!({ error: "You are not authorized to view this unit's analytics" }, 403) unless can_view_unit_analytics?(current_user, unit)

    #   analytics = unit.get_tutor_times(start_date: params[:start_date], end_date: params[:end_date])
    #   present analytics
    # end

    # desc "Get aggregated marking analytics for a specific unit"
    # params do
    #   requires :unit_id, type: Integer, desc: "Unit ID"
    #   optional :start_date, type: Date, desc: "Start date for analytics"
    #   optional :end_date, type: Date, desc: "End date for analytics"
    # end
    # get 'unit/:unit_id' do
    #   unit = Unit.find_by(id: params[:unit_id])

    #   error!({ error: "You are not authorized to view this unit's analytics" }, 403) unless can_view_unit_analytics?(current_user, unit)

    #   analytics = unit.get_tutor_times(start_date: params[:start_date], end_date: params[:end_date])
    #   present analytics
    # end
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
      return session.user_id == user.id if tutor_user?(user)
      return session.unit.unit_roles.exists?(user_id: user.id, role_id: Role.convenor.id) if convenor_user?(user)
      false
    end

    def can_view_tutor_sessions?(user, tutor)
      return true if admin_user?(user)
      return true if user.id == tutor.id
      if convenor_user?(user)
        tutor.unit_roles.pluck(:unit_id).intersect?(user.unit_roles.where(role_id: Role.convenor.id).pluck(:unit_id))
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
