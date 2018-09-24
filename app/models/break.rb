class Break < ActiveRecord::Base
  belongs_to :teaching_period

  validates :start_date, presence: true
  validates :number_of_weeks, presence: true
  validates :teaching_period_id, presence: true

  validate :ensure_start_date_is_within_teaching_period, :ensure_break_end_is_within_teaching_period

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
end