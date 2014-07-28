class Tutorial < ActiveRecord::Base
  # Model associations
  belongs_to :unit  # Foreign key
  belongs_to :unit_role              # Foreign key
  has_one    :tutor, through: :unit_role, source: :user

  has_many   :unit_roles, dependent: :nullify # Students
  has_many   :projects, through: :unit_roles, dependent: :nullify

  def self.default
    tutorial = self.new

    tutorial.unit_role_id     = -1
    tutorial.meeting_day      = "Enter a regular meeting day."
    tutorial.meeting_time     = "Enter a regular meeting time."
    tutorial.meeting_location = "Enter a location."

    tutorial
  end
  
  def self.find_by_user(user)
    Tutorial.joins(:tutor).where('user_id = :user_id', user_id: user.id)
  end

  def tutor
    result = UnitRole.find_by_id(unit_role_id)
    result.user unless result.nil?
  end
  
  def name
    # TODO: Will probably need to make this more flexible when
    # a tutorial is representing something other than a tutorial
    "#{meeting_day} #{meeting_time} (#{meeting_location})"
  end

  def status_distribution
    Project.status_distribution(projects)
  end

  def change_tutor(new_tutor)
    # Get the unit role for current tutor
    # previous_tutor_unit_role = unit_role.id
    assign_tutor(new_tutor)

    # # If we had a tutor previously
    # if !previous_tutor_unit_role.nil?
    #   # Get the remaining number of tutorials for the tutor in the given unit
    #   remaining_tutorials_for_previous_tutor = Tutorial.where(unit_role_id: previous_tutor_unit_role).count

    #   # Kill the tutor's tutor role if they no longer have any tutorials
    #   if remaining_tutorials_for_previous_tutor == 0
    #     UnitRole.destroy(previous_tutor_unit_role)
    #   end
    # end
  end

  def assign_tutor(tutor_user)
    # Create a role for the user if they're not already a tutor
    # TODO: Move creation to UnitRole and pass it approriate params
    tutor_unit_role = UnitRole.find_by(
      unit_id: unit_id,
      user_id: tutor_user.id,
    )

    if tutor_unit_role && tutor_user.has_tutor_capability? && (tutor_unit_role.role == Role.tutor || tutor_unit_role.role == Role.convenor)
      self.unit_role = tutor_unit_role
      save
    end
    self
  end
end