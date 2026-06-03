class CommunicationSetSchedule < ApplicationRecord
  RECURRENCES = %w[none daily weekly monthly].freeze
  VALID_DAYS = Date::DAYNAMES.freeze
  DAY_ABBREVIATIONS = Date::ABBR_DAYNAMES.freeze

  belongs_to :communication_set, class_name: 'CommunicationSet', inverse_of: :communication_set_schedules
  delegate :unit, to: :communication_set

  validates :name, presence: true
  validates :anchor_week, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :anchor_day, presence: true
  validates :hour, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 24 }
  validates :minute, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 60 }
  validates :interval, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :recurrence, presence: true, inclusion: { in: RECURRENCES }
  validates :repeat_count, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :active, inclusion: { in: [true, false] }
  validate :anchor_day_supported
  validate :timezone_supported
  validate :anchor_date_resolves

  before_validation :normalize_anchor_day
  before_validation :default_timezone
  before_validation :sync_schedule_cache

  scope :active, -> { where(active: true) }
  scope :due, ->(time = Time.zone.now) { where('next_run_at IS NOT NULL AND next_run_at <= ?', time) }
  scope :with_active_unit, -> { joins(communication_set: :unit).where(units: { active: true }) }

  def resolved_anchor_date
    return nil if unit.blank? || anchor_week.blank? || anchor_day.blank?

    unit.date_for_week_and_day(anchor_week, anchor_day_abbreviation)
  end

  def resolved_start_at
    date = resolved_anchor_date
    return nil if date.nil?

    timezone_object.local(date.year, date.month, date.day, hour, minute)
  end

  def build_ice_cube_schedule
    start_at = resolved_start_at
    return nil if start_at.nil?

    schedule = IceCube::Schedule.new(start_at)
    rule = recurrence_rule
    schedule.add_recurrence_rule(rule) if rule
    schedule
  end

  def next_occurrence_after(time = Time.zone.now)
    schedule = build_ice_cube_schedule
    return nil if schedule.nil?

    time_for_schedule = time.in_time_zone(timezone_object)
    if recurrence == 'none'
      occurrence = schedule.start_time
      occurrence >= time_for_schedule ? occurrence : nil
    else
      schedule.next_occurrence(time_for_schedule)
    end
  end

  def due?(time = Time.zone.now)
    active_for_scheduling? && next_run_at.present? && next_run_at <= time
  end

  def refresh_next_run_at!(from_time = Time.zone.now)
    update!(next_run_at: active_for_scheduling? ? next_occurrence_after(from_time) : nil)
  end

  def anchor_day_abbreviation
    return nil if anchor_day.blank?

    day = anchor_day.to_s.strip
    return day if DAY_ABBREVIATIONS.include?(day)

    index = VALID_DAYS.index(day.titlecase)
    index.nil? ? nil : DAY_ABBREVIATIONS[index]
  end

  private

  def recurrence_rule
    case recurrence
    when 'daily'
      IceCube::Rule.daily(interval)
    when 'weekly'
      IceCube::Rule.weekly(interval)
    when 'monthly'
      IceCube::Rule.monthly(interval)
    end&.tap do |rule|
      rule.count(repeat_count) if repeat_count.present?
      rule.until(until_at.in_time_zone(timezone_object)) if until_at.present?
    end
  end

  def timezone_object
    ActiveSupport::TimeZone[timezone.presence || Time.zone.name] || Time.zone
  end

  def normalize_anchor_day
    return if anchor_day.blank?

    full_day =
      if VALID_DAYS.include?(anchor_day.to_s.titlecase)
        anchor_day.to_s.titlecase
      else
        day_index = DAY_ABBREVIATIONS.index(anchor_day.to_s.titlecase)
        day_index.nil? ? anchor_day : VALID_DAYS[day_index]
      end

    self.anchor_day = full_day
  end

  def default_timezone
    self.timezone = timezone.presence || Time.zone.name
  end

  def sync_schedule_cache
    schedule = build_ice_cube_schedule
    self.ice_cube_schedule = schedule.present? ? JSON.generate(schedule.to_hash) : nil
    self.next_run_at = next_occurrence_after(Time.zone.now) if active_for_scheduling? && should_refresh_next_run_at?
    self.next_run_at = nil unless active_for_scheduling?
  end

  def active_for_scheduling?
    active? && unit&.active?
  end

  def should_refresh_next_run_at?
    will_save_change_to_anchor_week? ||
      will_save_change_to_anchor_day? ||
      will_save_change_to_hour? ||
      will_save_change_to_minute? ||
      will_save_change_to_timezone? ||
      will_save_change_to_recurrence? ||
      will_save_change_to_interval? ||
      will_save_change_to_repeat_count? ||
      will_save_change_to_until_at? ||
      will_save_change_to_active? ||
      next_run_at.blank?
  end

  def anchor_day_supported
    return if anchor_day.blank? || VALID_DAYS.include?(anchor_day.to_s.titlecase)

    errors.add(:anchor_day, 'must be a valid day name')
  end

  def timezone_supported
    return if timezone.blank? || ActiveSupport::TimeZone[timezone].present?

    errors.add(:timezone, 'must be a valid timezone')
  end

  def anchor_date_resolves
    return if unit.blank? || anchor_week.blank? || anchor_day.blank?
    return if resolved_anchor_date.present?

    errors.add(:base, 'schedule anchor could not be resolved for this unit')
  end
end
