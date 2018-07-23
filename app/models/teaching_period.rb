class TeachingPeriod < ActiveRecord::Base
  has_many :units

  validates :period, length: { minimum: 1, maximum: 20, allow_blank: false }, uniqueness: true
  validates :year, length: { is: 4, allow_blank: false }, presence: true, numericality: { only_integer: true },
    inclusion: { in: 2000..2099, message: "%{value} is not a valid year" }
  validates :start_date, presence: true
  validates :end_date, presence: true

  validate :validate_end_date_after_start_date

  def validate_end_date_after_start_date
    if end_date < start_date
      errors.add(:end_date, "should be after the Start date")
    end
  end

  def roll_over(unit_id)
    current_unit = Unit.find(unit_id)
    new_unit = current_unit.dup
    new_unit.save!

    add_task_definitions(current_unit, new_unit)
    new_unit
  end

  def add_task_definitions(current_unit, new_unit)
    current_unit.task_definitions.each do |task_definitions|
      new_unit.task_definitions << task_definitions.dup
    end
  end
end
