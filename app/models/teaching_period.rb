class TeachingPeriod < ActiveRecord::Base
  has_many :units
  has_many :breaks

  validates :period, length: { minimum: 1, maximum: 20, allow_blank: false }, uniqueness: { scope: :year,
    message: "%{value} already exists in this year" }
  validates :year, length: { is: 4, allow_blank: false }, presence: true, numericality: { only_integer: true },
    inclusion: { in: 2000..2999, message: "%{value} is not a valid year" }
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :active_until, presence: true

  validate :validate_end_date_after_start_date, :validate_active_until_after_end_date

  def validate_end_date_after_start_date
    if end_date.present? && start_date.present? && end_date < start_date
      errors.add(:end_date, "should be after the Start date")
    end
  end

  def validate_active_until_after_end_date
    if end_date.present? && active_until.present? && active_until < end_date
      errors.add(:active_until, "date should be after the End date")
    end
  end

  def add_break(start_date, number_of_weeks)
    break_in_teaching_period = Break.new
    break_in_teaching_period.start_date = start_date
    break_in_teaching_period.number_of_weeks = number_of_weeks
    break_in_teaching_period.teaching_period_id = self.id
    break_in_teaching_period.save!
    break_in_teaching_period
  end

  def rollover(rollover_to)
    rollover_to.add_associations(self)
    rollover_to.save!
    rollover_to
  end

  def add_associations(existing_teaching_period)
    duplicate_units_from_existing_teaching_period(existing_teaching_period)
  end

  def duplicate_units_from_existing_teaching_period(existing_teaching_period)
    for unit in existing_teaching_period.units do
      unit.rollover(self.id, nil, nil)
    end
  end
end
