# frozen_string_literal: true

# A user's notification settings: the one digest schedule they choose, and the
# channel defaults every unit follows until it is customised.
class NotificationSetting < ApplicationRecord
  FREQUENCIES = %w[off hourly daily weekly].freeze
  DIGEST_INTERVAL_HOURS = [1, 2, 3, 4, 6, 12].freeze
  TIME_FORMAT = /\A(?:[01]\d|2[0-3]):[0-5]\d\z/

  attribute :channels, :json

  belongs_to :user

  validates :channels, notification_channels: true
  validates :digest_frequency, inclusion: { in: FREQUENCIES }
  validates :digest_interval_hours, inclusion: { in: DIGEST_INTERVAL_HOURS }
  validates :digest_start_time, format: { with: TIME_FORMAT }
  validates :digest_time, format: { with: TIME_FORMAT }
  validates :digest_weekday, inclusion: { in: 1..7 }
  validate :digest_timezone_supported

  before_validation :apply_defaults
  before_save :refresh_next_digest_at, if: :schedule_changed?
  after_commit :process_pending_notifications, if: :saved_change_to_digest_off?

  scope :due, -> { where.not(digest_frequency: 'off').where(next_digest_at: ..Time.current) }

  def self.for(user)
    find_or_create_by!(user: user)
  rescue ActiveRecord::RecordNotUnique
    find_by!(user: user)
  end

  def self.default_channels
    Notification::KINDS.index_with do |kind|
      Notification::COMMUNICATION_KINDS.include?(kind) ? ['in_app'] : %w[in_app email]
    end
  end

  def self.default_digest_timezone
    configured_timezone = ENV.fetch('TZ', nil).presence
    return configured_timezone if ActiveSupport::TimeZone[configured_timezone].present?

    Time.zone.tzinfo.name
  end

  # Use the first unit the user enrolled in as their home campus for now.
  def resolved_digest_timezone
    first_project = user.projects.where(enrolled: true).order(:id).includes(:campus).first
    first_project&.campus&.timezone.presence || self.class.default_digest_timezone
  end

  # The channels a unit delivers a kind on, honouring its override when it has
  # one. A muted unit delivers nothing.
  def channels_for_unit_id(unit_id, kind)
    override = override_for(unit_id)
    return [] if override&.muted
    return ['in_app'] if Notification::COMMUNICATION_KINDS.include?(kind.to_s)

    Array((override&.customised? ? override.channels : channels)[kind.to_s])
  end

  def delivers?(unit, kind, channel)
    channels_for_unit_id(unit&.id, kind).include?(channel.to_s)
  end

  def weekly_summary_for?(unit)
    return false unless weekly_summary

    override = user.notification_unit_overrides.find_by(unit_id: unit&.id)
    !override&.muted
  end

  # Notifications are always recorded so the digest has something to send, so the
  # in-app list has to filter them out rather than rely on them never existing.
  def shows_in_app?(unit_id, kind)
    channels_for_unit_id(unit_id, kind).include?('in_app')
  end

  def advance_digest!(from: Time.current)
    update!(last_digest_at: from, next_digest_at: next_occurrence(from))
  end

  def next_occurrence(from = Time.current)
    return nil if digest_frequency == 'off'

    local_from = from.in_time_zone(digest_time_zone)
    if digest_frequency == 'hourly'
      start_hour, start_minute = digest_start_time.split(':').map(&:to_i)
      return next_hourly_occurrence(local_from, start_hour, start_minute)
    end

    hour, minute = digest_time.split(':').map(&:to_i)
    date = local_from.to_date
    date += (digest_weekday - date.cwday) % 7 if digest_frequency == 'weekly'

    candidate = digest_time_zone.local(date.year, date.month, date.day, hour, minute)
    candidate += digest_frequency == 'weekly' ? 1.week : 1.day if candidate <= local_from
    candidate
  end

  private

  def override_for(unit_id)
    return nil if unit_id.nil?

    @overrides_by_unit ||= user.notification_unit_overrides.index_by(&:unit_id)
    @overrides_by_unit[unit_id]
  end

  def apply_defaults
    self.channels = self.class.default_channels if channels.nil?
    self.digest_timezone = resolved_digest_timezone
  end

  def refresh_next_digest_at
    self.next_digest_at = next_occurrence(Time.current)
  end

  def schedule_changed?
    next_digest_at.nil? ||
      will_save_change_to_digest_frequency? ||
      will_save_change_to_digest_interval_hours? ||
      will_save_change_to_digest_start_time? ||
      will_save_change_to_digest_time? ||
      will_save_change_to_digest_timezone? ||
      will_save_change_to_digest_weekday?
  end

  def saved_change_to_digest_off?
    digest_frequency == 'off' && saved_change_to_digest_frequency?
  end

  # The start time anchors the wall-clock slots, which continue across midnight.
  # Rebuilding them each day avoids job delays and daylight-saving changes
  # shifting the user's schedule.
  def next_hourly_occurrence(from, hour, minute)
    date = from.to_date
    candidate_hours = (24 / digest_interval_hours).times.map do |offset|
      (hour + (offset * digest_interval_hours)) % 24
    end.sort
    candidates = candidate_hours.map do |candidate_hour|
      digest_time_zone.local(date.year, date.month, date.day, candidate_hour, minute)
    end

    candidates.find { |candidate| candidate > from } || begin
      next_date = date + 1.day
      digest_time_zone.local(next_date.year, next_date.month, next_date.day, candidate_hours.first, minute)
    end
  end

  def digest_time_zone
    ActiveSupport::TimeZone[resolved_digest_timezone]
  end

  def digest_timezone_supported
    return if digest_timezone.present? && digest_time_zone.present?

    errors.add(:digest_timezone, 'must be a valid timezone')
  end

  # Nothing is left waiting for a digest that will never run.
  def process_pending_notifications
    now = Time.current
    # rubocop:disable Rails/SkipsModelValidations
    user.received_notifications
        .email_pending
        .update_all(email_processed_at: now, updated_at: now)
    # rubocop:enable Rails/SkipsModelValidations
  end
end
