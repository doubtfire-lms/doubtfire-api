# frozen_string_literal: true

class NotificationPreference < ApplicationRecord
  FREQUENCIES = %w[off hourly daily weekly].freeze
  TIME_FORMAT = /\A(?:[01]\d|2[0-3]):[0-5]\d\z/

  attribute :email_categories, :json

  belongs_to :user
  belongs_to :unit

  validates :email_frequency, inclusion: { in: FREQUENCIES }
  validates :email_time, format: { with: TIME_FORMAT }
  validates :email_weekday, inclusion: { in: 1..7 }
  validates :timezone, presence: true
  validate :valid_timezone
  validate :valid_email_categories

  before_validation :apply_defaults
  before_validation :normalize_email_categories
  before_save :refresh_next_digest_at, if: :schedule_changed?
  after_commit :process_pending_notifications_when_off, if: :saved_change_to_off?

  scope :due, -> { where.not(email_frequency: 'off').where(next_digest_at: ..Time.current) }

  def self.for(user, unit)
    find_or_create_by!(user: user, unit: unit) do |preference|
      preference.email_categories = default_categories(user)
      preference.timezone = default_timezone(user, unit)
    end
  end

  def self.default_categories(user)
    categories = ['tutor_note']
    categories.push('feedback_left', 'task_status_changed', 'discuss_warning', 'discuss_expired') if user.receive_feedback_notifications
    categories.push('overseer_failed', 'pdf_generation_failed') if user.receive_task_notifications
    categories.uniq
  end

  def self.default_timezone(user, unit)
    return Time.zone.name if unit.unit_roles.exists?(user_id: user.id)

    Project.find_by(user: user, unit: unit)&.campus&.timezone.presence || Time.zone.name
  end

  def email_enabled_for?(kind)
    email_frequency != 'off' && email_categories.include?(kind)
  end

  def advance_digest!(from: Time.current)
    update!(last_digest_at: from, next_digest_at: next_occurrence(from))
  end

  def next_occurrence(from = Time.current)
    return nil if email_frequency == 'off'

    zone = timezone_object
    local_from = from.in_time_zone(zone)
    return (local_from.beginning_of_hour + 1.hour).utc if email_frequency == 'hourly'

    hour, minute = email_time.split(':').map(&:to_i)
    candidate_date = local_from.to_date

    if email_frequency == 'weekly'
      days_ahead = (email_weekday - candidate_date.cwday) % 7
      candidate_date += days_ahead.days
    end

    candidate = zone.local(candidate_date.year, candidate_date.month, candidate_date.day, hour, minute)
    candidate += email_frequency == 'weekly' ? 1.week : 1.day if candidate <= local_from
    candidate.utc
  end

  def timezone_object
    ActiveSupport::TimeZone[timezone] || Time.zone
  end

  private

  def apply_defaults
    self.email_categories ||= self.class.default_categories(user)
    self.email_frequency ||= 'weekly'
    self.email_time ||= '09:00'
    self.email_weekday ||= 1
    self.timezone ||= self.class.default_timezone(user, unit)
  end

  def refresh_next_digest_at
    self.next_digest_at = next_occurrence(Time.current)
  end

  def schedule_changed?
    next_digest_at.nil? ||
      will_save_change_to_email_frequency? ||
      will_save_change_to_email_time? ||
      will_save_change_to_email_weekday? ||
      will_save_change_to_timezone?
  end

  def valid_timezone
    errors.add(:timezone, 'must be a valid timezone') if timezone.present? && ActiveSupport::TimeZone[timezone].nil?
  end

  def valid_email_categories
    unless email_categories.is_a?(Array)
      errors.add(:email_categories, 'must be an array')
      return
    end

    invalid = Array(email_categories) - Notification::KINDS
    errors.add(:email_categories, "contains unsupported categories: #{invalid.join(', ')}") if invalid.any?
  end

  def normalize_email_categories
    return unless email_categories.is_a?(String)

    parsed = JSON.parse(email_categories)
    self.email_categories = parsed if parsed.is_a?(Array)
  rescue JSON::ParserError
    nil
  end

  def saved_change_to_off?
    email_frequency == 'off' && saved_change_to_email_frequency?
  end

  def process_pending_notifications_when_off
    now = Time.current
    # These are delivery-ledger updates and intentionally bypass callbacks.
    # rubocop:disable Rails/SkipsModelValidations
    user.received_notifications.where(unit: unit).email_pending.update_all(
      email_processed_at: now,
      updated_at: now
    )
    # rubocop:enable Rails/SkipsModelValidations
  end
end
