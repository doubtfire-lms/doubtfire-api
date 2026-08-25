# frozen_string_literal: true

require 'grape'

class NotificationsApi < Grape::API
  helpers AuthenticationHelpers

  before do
    authenticated?
  end

  helpers do
    def notification_settings
      @notification_settings ||= NotificationSetting.for(current_user)
    end

    def notification_scope
      current_user
        .received_notifications
        .includes(:recipient, :unit, task: [:task_definition, { project: :user }])
    end

    # Kinds the user has switched off in the app stay in the ledger for the
    # digest, so they are dropped here rather than never recorded.
    def shown_in_app(notifications)
      notifications.select { |notification| notification_settings.shows_in_app?(notification.unit_id, notification.kind) }
    end

    def unread_group_count
      rows = current_user.received_notifications.unread.pluck(:task_id, :unit_id, :kind, :metadata)
      rows.select { |_task_id, unit_id, kind, _metadata| notification_settings.shows_in_app?(unit_id, kind) }.map do |task_id, unit_id, kind, metadata|
        if task_id.present?
          "task:#{task_id}"
        elsif Notification::MODERATION_KINDS.include?(kind)
          "tutor-notes:#{unit_id}:#{metadata['unit_role_id']}"
        else
          "unit:#{unit_id}:#{kind}"
        end
      end.uniq.count
    end

    def serialize_settings(settings)
      {
        id: settings.id,
        channels: settings.channels,
        digest_frequency: settings.digest_frequency,
        digest_time: settings.digest_time,
        digest_weekday: settings.digest_weekday,
        weekly_summary: settings.weekly_summary,
        next_digest_at: settings.next_digest_at,
        last_digest_at: settings.last_digest_at,
        units: current_user.notification_preferences.order(:unit_id).map { |preference| serialize_preference(preference) }
      }
    end

    def serialize_preference(preference)
      {
        unit_id: preference.unit_id,
        muted: preference.muted,
        channels: preference.channels
      }
    end

    # The units sent are the whole set that departs from the defaults, so any unit
    # missing from it has been reset and no longer needs a row.
    def replace_unit_preferences(units)
      accessible = accessible_unit_ids
      wanted = Array(units).select { |unit| accessible.include?(unit[:unit_id]) }

      current_user.notification_preferences.where.not(unit_id: wanted.map { |unit| unit[:unit_id] }).destroy_all
      wanted.each do |unit|
        preference = current_user.notification_preferences.find_or_initialize_by(unit_id: unit[:unit_id])
        preference.update!(muted: unit[:muted], channels: unit[:channels])
      end
    end

    def accessible_unit_ids
      project_units = current_user.projects.where(enrolled: true).select(:unit_id)
      role_units = current_user.unit_roles.select(:unit_id)

      Unit.where(id: project_units).or(Unit.where(id: role_units)).pluck(:id)
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

    groups = NotificationGroupBuilder.new(shown_in_app(scope)).groups
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

  desc 'Get the notification settings for the current user'
  get '/notification_settings' do
    serialize_settings(NotificationSetting.for(current_user))
  end

  desc 'Update the notification settings for the current user'
  params do
    optional :channels, type: Hash
    optional :digest_frequency, type: String, values: NotificationSetting::FREQUENCIES
    optional :digest_time, type: String
    optional :digest_weekday, type: Integer
    optional :weekly_summary, type: Boolean
    optional :units, type: Array do
      requires :unit_id, type: Integer
      requires :muted, type: Boolean
      optional :channels, type: Hash
    end
  end
  put '/notification_settings' do
    settings = NotificationSetting.for(current_user)
    changes = declared(params, include_missing: false)

    NotificationSetting.transaction do
      settings.update!(changes.except(:units))
      replace_unit_preferences(changes[:units]) if changes.key?(:units)
    end

    serialize_settings(settings)
  end
end
