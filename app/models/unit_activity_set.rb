class UnitActivitySet < ActiveRecord::Base
  belongs_to :unit
  belongs_to :activity_type

  has_many :campus_activity_sets, dependent: :destroy
  has_many :tutorials,            dependent: :destroy

  # Always check for presence of whole model instead of id
  # So validate presence of unit not unit_id
  # This ensures that id provided is also valid, so there exists an unit with that id
  validates :activity_type, presence: true
  validates :unit,          presence: true

  # Always add a unique index to the DB to prevent new records from passing the validations when checked at the same time before being written
  # For reference, see unique index migrations of unit activity sets
  validates_uniqueness_of :activity_type, :scope => :unit, message: 'already exists for the unit'

  def add_tutorial(day, time, location, tutor, campus, capacity, abbrev)
    tutor_role = unit.unit_roles.where('user_id=:user_id', user_id: tutor.id).first
    return nil if tutor_role.nil? || tutor_role.role == Role.student

    tutorial = Tutorial.new
    tutorial.unit = unit
    tutorial.unit_activity_set = self
    tutorial.campus = campus
    tutorial.capacity = capacity
    tutorial.abbreviation = abbrev
    tutorial.meeting_day = day
    tutorial.meeting_time = time
    tutorial.meeting_location = location
    tutorial.unit_role_id = tutor_role.id

    tutorial.save!

    # add after save to ensure valid tutorials
    self.tutorials << tutorial

    tutorial
  end
end
