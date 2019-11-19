class Tutorial < ActiveRecord::Base
  # Model associations
  belongs_to :unit # Foreign key
  belongs_to :unit_role # Foreign key
  belongs_to :campus
  belongs_to :tutorial_stream

  has_one    :tutor, through: :unit_role, source: :user

  has_many   :groups, dependent: :nullify
  has_many   :tutorial_enrolments
  has_many   :projects, through: :tutorial_enrolments

  # Callbacks - methods called are private
  before_destroy :can_destroy?

  validates :abbreviation, uniqueness: { scope: :unit,
                                         message: 'must be unique within the unit' }

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
    result = UnitRole.find_by(id: unit_role_id)
    result.user unless result.nil?
  end

  def name
    # TODO: Will probably need to make this more flexible when
    # a tutorial is representing something other than a tutorial
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
    return true if tutorial_enrolments.count == 0
    errors.add :base, "Cannot delete tutorial with enrolments"
    false
  end
end
