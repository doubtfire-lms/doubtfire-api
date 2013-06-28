class Tutorial < ActiveRecord::Base
  attr_accessible :unit_id, :user_id, :code, :meeting_day, :meeting_location, :meeting_time

  # Model associations
  belongs_to :unit  # Foreign key
  belongs_to :unit_role              # Foreign key
  has_one    :tutor, through: :unit_role, source: :user
  has_many   :unit_roles
  has_many   :projects, through: :unit_roles

  def self.default
    tutorial = self.new

    tutorial.unit_role_id     = -1
    tutorial.meeting_day      = "Enter a regular meeting day."
    tutorial.meeting_time     = "Enter a regular meeting time."
    tutorial.meeting_location = "Enter a location."

    tutorial
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
    previous_tutor_unit_role = unit_role.id
    assign_tutor(new_tutor)

    # If we had a tutor previously
    if !previous_tutor_unit_role.nil?
      # Get the remaining number of tutorials for the tutor in the given unit
      remaining_tutorials_for_previous_tutor = Tutorial.where(unit_role_id: previous_tutor_unit_role).count

      # Kill the tutor's tutor role if they no longer have any tutorials
      if remaining_tutorials_for_previous_tutor == 0
        UnitRole.destroy(previous_tutor_unit_role)
      end
    end
  end

  def assign_tutor(tutor_user)
    # Create a role for the user if they're not already a tutor
    # TODO: Move creation to UnitRole and pass it approriate params
    tutor_unit_role = UnitRole.find_or_create_by_unit_id_and_user_id_and_role_id(
      unit_id: unit_id,
      user_id: tutor_user.id,
      role_id: Role.where(name: 'Tutor').first.id
    )

    tutor_unit_role.save
    self.unit_role = tutor_unit_role

    save
  end
end