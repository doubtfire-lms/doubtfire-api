class Break < ApplicationRecord
  belongs_to :teaching_period, optional: false

  after_save :refresh_teaching_period_communication_schedule_caches
  after_destroy :refresh_teaching_period_communication_schedule_caches

  validates :start_date, presence: true
  validates :number_of_days, presence: true
  validates :teaching_period_id, presence: true
  validate :ensure_campuses_exist
  validate :ensure_pause_week_count_is_whole_weeks

  validate :ensure_start_date_is_within_teaching_period, :ensure_break_end_is_within_teaching_period, :ensure_break_is_not_colliding

  def ensure_start_date_is_within_teaching_period
    if start_date < teaching_period.start_date
      errors.add(:start_date, "should be after the Teaching Period start date")
    end
  end

  def ensure_break_end_is_within_teaching_period
    if start_date + number_of_days.days > teaching_period.end_date
      errors.add(:number_of_days, "is exceeding Teaching Period end date")
    end
  end

  def ensure_break_is_not_colliding
    for break_in_teaching_period in teaching_period.breaks do
      same_scope = campuses_overlap?(break_in_teaching_period)
      dates_overlap = break_in_teaching_period.end_date >= start_date && break_in_teaching_period.start_date <= end_date
      if break_in_teaching_period.id != id && same_scope && dates_overlap
        errors.add(:base, "overlaps another break")
        break
      end
    end
  end

  def duration
    number_of_days.days
  end

  # The number of whole teaching weeks this break spans - partial weeks count as
  # a full week, as teaching weeks cannot be split.
  def weeks_spanned
    (number_of_days / 7.0).ceil
  end

  def first_monday
    return start_date if start_date.wday == 1
    return start_date + 1.day if start_date.wday == 0

    return start_date + (8 - start_date.wday).days
  end

  def monday_after_break
    first_monday + number_of_days.days
  end

  def end_date
    start_date + duration
  end

  def campus_ids
    value = super
    value.is_a?(String) ? JSON.parse(value) : Array(value)
  rescue JSON::ParserError
    []
  end

  def applies_to?(campus)
    campus_ids.blank? || (campus.present? && campus_ids.map(&:to_i).include?(campus.id))
  end

  private

  def campuses_overlap?(other_break)
    campus_ids.blank? ||
      other_break.campus_ids.blank? ||
      campus_ids.map(&:to_i).intersect?(other_break.campus_ids.map(&:to_i))
  end

  def ensure_pause_week_count_is_whole_weeks
    return unless pause_week_count?
    return if number_of_days.blank?

    unless (number_of_days % 7).zero?
      errors.add(:pause_week_count, 'can only be set on breaks that are a multiple of 7 days')
    end
  end

  def ensure_campuses_exist
    invalid_ids = Array(campus_ids).map(&:to_i) - Campus.where(id: campus_ids).pluck(:id)
    errors.add(:campus_ids, 'contains an invalid campus') if invalid_ids.any?
  end

  def refresh_teaching_period_communication_schedule_caches
    teaching_period.refresh_communication_schedule_caches
  end
end
