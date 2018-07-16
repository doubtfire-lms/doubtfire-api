class TeachingPeriod < ActiveRecord::Base
  has_many :units

  validates :period, length: { minimum: 1, maximum: 20, allow_blank: false }, uniqueness: true
  validates :start_date, presence: true
  validates :end_date, presence: true

  validate :validate_end_date_after_start_date

  def validate_end_date_after_start_date
    if end_date < start_date
      errors.add(:end_date, "should be after the Start date")
    end
  end

  def roll_over(unit_id)
    new_unit = Unit.find(unit_id).dup
    new_unit.save!
    new_unit
  end
end
