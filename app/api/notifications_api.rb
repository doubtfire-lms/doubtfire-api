# frozen_string_literal: true

require 'grape'

class NotificationsApi < Grape::API
  helpers AuthenticationHelpers

  before do
    authenticated?
  end

  helpers do
    def notification_scope
      current_user
        .received_notifications
        .includes(:recipient, :unit, task: [:task_definition, { project: :user }])
    end

    def unread_group_count
      current_user.received_notifications.unread.pluck(:task_id, :unit_id, :kind, :metadata).map do |task_id, unit_id, kind, metadata|
        if task_id.present?
          "task:#{task_id}"
        elsif kind == 'tutor_note'
          "tutor-notes:#{unit_id}:#{metadata['unit_role_id']}"
        else
          "unit:#{unit_id}:#{kind}"
        end
      end.uniq.count
    end

    def serialize_preference(preference)
      {
        id: preference.id,
        unit: {
          id: preference.unit.id,
          code: preference.unit.code,
          name: preference.unit.name
        },
        email_categories: preference.email_categories,
        email_frequency: preference.email_frequency,
        email_time: preference.email_time,
        email_weekday: preference.email_weekday,
        timezone: preference.timezone,
        next_digest_at: preference.next_digest_at,
        last_digest_at: preference.last_digest_at
      }
    end

    def accessible_unit_ids
      project_units = current_user.projects.where(enrolled: true).select(:unit_id)
      role_units = current_user.unit_roles.select(:unit_id)
      preference_units = current_user.notification_preferences.select(:unit_id)

      Unit.where(id: project_units).or(Unit.where(id: role_units)).or(Unit.where(id: preference_units)).pluck(:id)
    end
  end

  desc 'Get grouped notifications for the current user'
  params do
    optional :state, type: String, values: %w[all unread read], default: 'all'
    optional :unit_id, type: Integer
    optional :kinds, type: Array[String], values: Notification::KINDS
    optional :query, type: String
    optional :page, type: Integer, default: 1, values: ->(value) { value.positive? }
    optional :per_page, type: Integer, default: 25, values: 1..50
  end
  get '/notifications' do
    scope = notification_scope
    scope = scope.where(unit_id: params[:unit_id]) if params[:unit_id]
    scope = scope.where(kind: params[:kinds]) if params[:kinds].present?

    scope =
      case params[:state]
      when 'unread'
        scope.unread
      when 'read'
        scope.recently_read
      else
        scope.where('notifications.read_at IS NULL OR notifications.read_at >= ?', 30.days.ago)
      end

    groups = NotificationGroupBuilder.new(scope).groups
    if params[:query].present?
      query = params[:query].downcase
      groups.select! do |group|
        [
          group[:summary],
          group.dig(:unit, :code),
          group.dig(:unit, :name),
          group.dig(:task, :abbreviation),
          group.dig(:task, :name),
          group.dig(:task, :student_name)
        ].compact.any? { |value| value.to_s.downcase.include?(query) }
      end
    end

    page = params[:page]
    per_page = params[:per_page]
    total = groups.count

    {
      groups: groups.slice((page - 1) * per_page, per_page) || [],
      page: page,
      per_page: per_page,
      total: total,
      unread_count: unread_group_count
    }
  end

  desc 'Get the grouped unread notification count for the current user'
  get '/notifications/unread_count' do
    { count: unread_group_count }
  end

  desc 'Mark selected notifications as read'
  params do
    requires :notification_ids, type: Array[Integer]
  end
  put '/notifications/read' do
    scope = current_user.received_notifications.where(id: params[:notification_ids]).unread
    count = scope.count
    Notification.mark_read(scope)
    { count: count }
  end

  desc 'Mark all notifications as read'
  params do
    optional :unit_id, type: Integer
  end
  put '/notifications/read_all' do
    scope = current_user.received_notifications.unread
    scope = scope.where(unit_id: params[:unit_id]) if params[:unit_id]
    count = scope.count
    Notification.mark_read(scope)
    { count: count }
  end

  desc 'Get per-unit notification email preferences'
  get '/notification_preferences' do
    preferences = Unit.where(id: accessible_unit_ids).order(:code).map do |unit|
      NotificationPreference.for(current_user, unit)
    end

    preferences.map { |preference| serialize_preference(preference) }
  end

  desc 'Update notification email preferences for a unit'
  params do
    requires :email_categories, type: Array[String], values: Notification::KINDS
    requires :email_frequency, type: String, values: NotificationPreference::FREQUENCIES
    requires :email_time, type: String
    requires :email_weekday, type: Integer
    requires :timezone, type: String
  end
  put '/notification_preferences/:unit_id' do
    unit_id = params[:unit_id].to_i
    error!({ error: 'You do not have access to notification settings for this unit' }, 403) unless accessible_unit_ids.include?(unit_id)

    preference = NotificationPreference.for(current_user, Unit.find(unit_id))
    preference.update!(
      email_categories: params[:email_categories],
      email_frequency: params[:email_frequency],
      email_time: params[:email_time],
      email_weekday: params[:email_weekday],
      timezone: params[:timezone]
    )

    serialize_preference(preference)
  end
end
