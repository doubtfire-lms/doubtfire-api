# frozen_string_literal: true

# A user's notification settings: the one digest schedule they choose, and the
# channel defaults every unit follows until it is customised.
class NotificationSetting < ApplicationRecord
  FREQUENCIES = %w[off hourly daily weekly].freeze
  TIME_FORMAT = /\A(?:[01]\d|2[0-3]):[0-5]\d\z/

  attribute :channels, :json

  belongs_to :user

  validates :channels, notification_channels: true
  validates :digest_frequency, inclusion: { in: FREQUENCIES }
  validates :digest_time, format: { with: TIME_FORMAT }
  validates :digest_weekday, inclusion: { in: 1..7 }

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
    Notification::KINDS.index_with { %w[in_app email] }
  end

  # The channels a unit delivers a kind on, honouring its override when it has
  # one. A muted unit delivers nothing.
  def channels_for_unit_id(unit_id, kind)
    override = override_for(unit_id)
    return [] if override&.muted

    Array((override&.customised? ? override.channels : channels)[kind.to_s])
  end

  def delivers?(unit, kind, channel)
    channels_for_unit_id(unit&.id, kind).include?(channel.to_s)
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
    return from.beginning_of_hour + 1.hour if digest_frequency == 'hourly'

    hour, minute = digest_time.split(':').map(&:to_i)
    date = from.to_date
    date += (digest_weekday - date.cwday) % 7 if digest_frequency == 'weekly'

    candidate = Time.zone.local(date.year, date.month, date.day, hour, minute)
    candidate += digest_frequency == 'weekly' ? 1.week : 1.day if candidate <= from
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
  end

  def refresh_next_digest_at
    self.next_digest_at = next_occurrence(Time.current)
  end

  def schedule_changed?
    next_digest_at.nil? ||
      will_save_change_to_digest_frequency? ||
      will_save_change_to_digest_time? ||
      will_save_change_to_digest_weekday?
  end

  def saved_change_to_digest_off?
    digest_frequency == 'off' && saved_change_to_digest_frequency?
  end

  # Nothing is waiting for a digest that will never run. Alerts are unaffected -
  # they never went through the digest in the first place.
  def process_pending_notifications
    now = Time.current
    # rubocop:disable Rails/SkipsModelValidations
    user.received_notifications
        .email_pending
        .where.not(kind: Notification::DISCUSS_KINDS)
        .update_all(email_processed_at: now, updated_at: now)
    # rubocop:enable Rails/SkipsModelValidations
  end
end
