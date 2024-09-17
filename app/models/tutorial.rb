class Tutorial < ApplicationRecord
  # Model associations
  belongs_to :unit, optional: false # Foreign key
  belongs_to :unit_role, optional: true # Foreign key
  belongs_to :campus, optional: true
  belongs_to :tutorial_stream, optional: true

  has_one    :tutor, through: :unit_role, source: :user

  has_many   :groups, dependent: :restrict_with_exception
  has_many   :tutorial_enrolments, dependent: :destroy
  has_many   :projects, through: :tutorial_enrolments

  # Callbacks - methods called are private
  before_destroy :can_destroy?

  validates :abbreviation, uniqueness: { scope: :unit,
                                         message: 'must be unique within the unit' }

  # Make sure that unit in tutorial and tutorial stream are consistent
  validate :unit_must_be_same

  def unit_must_be_same
    if unit.present? and tutorial_stream.present? and !unit.eql? tutorial_stream.unit
      errors.add(:unit, "should be same as the unit in the associated tutorial stream")
    end
  end

  def self.default
    tutorial = new

    tutorial.unit_role_id     = -1
    tutorial.meeting_day      = 'Enter a regular meeting day.'
    tutorial.meeting_time     = 'Enter a regular meeting time.'
    tutorial.meeting_location = 'Enter a location.'

    tutorial
  end

  def self.find_by_user(user)
    Tutorial.joins(:tutor).where('user_id = :user_id', user_id: user.id)
  end

  def tutor
    unit_role.user unless unit_role.nil?
  end

  def name
    "#{meeting_day} #{meeting_time} (#{meeting_location})"
  end

  def change_tutor(new_tutor)
    # Get the unit role for current tutor
    assign_tutor(new_tutor)
  end

  def assign_tutor(tutor_user)
    # Create a role for the user if they're not already a tutor
    # TODO: Move creation to UnitRole and pass it approriate params
    tutor_unit_role = UnitRole.find_by(
      unit_id: unit_id,
      user_id: tutor_user.id
    )

    if tutor_unit_role && tutor_user.has_tutor_capability? && (tutor_unit_role.role == Role.tutor || tutor_unit_role.role == Role.convenor)
      self.unit_role = tutor_unit_role
      save
    end
    self
  end

  def num_students
    projects.where('enrolled = true').count
  end

  private

  def can_destroy?
    active_enrolment_count = num_students
    return true if active_enrolment_count == 0 && groups.count == 0

    errors.add :base, "Cannot delete tutorial with enrolments" if active_enrolment_count > 0
    errors.add :base, "Cannot delete tutorial with groups" if groups.count > 0
    throw :abort
  end
end
