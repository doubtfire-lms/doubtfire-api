class Break < ActiveRecord::Base
  belongs_to :teaching_period

  validates :start_date, presence: true
  validates :number_of_weeks, presence: true
  validates :teaching_period_id, presence: true

  validate :ensure_start_date_is_within_teaching_period

  def ensure_start_date_is_within_teaching_period
    if start_date < teaching_period.start_date
      errors.add(:start_date, "should be after the Teaching Period start date")
    end
  end
end