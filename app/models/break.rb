class Break < ActiveRecord::Base
  belongs_to :teaching_period

  validates :start_date, presence: true
  validates :number_of_weeks, presence: true
  validates :teaching_period_id, presence: true

  validate :ensure_start_date_is_within_teaching_period, :ensure_break_end_is_within_teaching_period, :ensure_break_is_not_colliding

  def ensure_start_date_is_within_teaching_period
    if start_date < teaching_period.start_date
      errors.add(:start_date, "should be after the Teaching Period start date")
    end
  end

  def ensure_break_end_is_within_teaching_period
    if start_date + number_of_weeks.weeks > teaching_period.end_date
      errors.add(:number_of_weeks, "is exceeding Teaching Period end date")
    end
  end

  def ensure_break_is_not_colliding
    for break_in_teaching_period in teaching_period.breaks do
      if break_in_teaching_period.id != id && break_in_teaching_period.end_date >= start_date && break_in_teaching_period.start_date <= end_date
        errors.add(:base, "overlaps another break")
        break
      end
    end
  end

  def duration
    number_of_weeks.weeks
  end

  def first_monday
    return start_date if start_date.wday == 1
    return start_date + 1.day if start_date.wday == 0
    return start_date + (8 - start_date.wday).days
  end

  def monday_after_break
    first_monday + number_of_weeks.weeks
  end

  def end_date
    start_date + duration
  end
end