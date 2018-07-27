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

  def add_teaching_period(new_unit)
    new_unit.teaching_period_id = self.id
  end

  def add_unit_associations(current_unit, new_unit)
    add_task_definitions(current_unit, new_unit)
    add_learning_outcomes(current_unit, new_unit)
    add_group_sets(current_unit, new_unit)
    add_convenors(current_unit, new_unit)
  end

  def add_task_definitions(current_unit, new_unit)
    current_unit.task_definitions.each do |task_definitions|
      new_unit.task_definitions << task_definitions.dup
    end
  end

  def add_learning_outcomes(current_unit, new_unit)
    current_unit.learning_outcomes.each do |learning_outcomes|
      new_unit.learning_outcomes << learning_outcomes.dup
    end
  end

  def add_group_sets(current_unit, new_unit)
    current_unit.group_sets.each do |group_sets|
      new_unit.group_sets << group_sets.dup
    end
  end

  def add_convenors(current_unit, new_unit)
    current_unit.convenors.each do |convenors|
      new_unit.convenors << convenors.dup
    end
  end
end
