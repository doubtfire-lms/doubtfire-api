class TutorialEnrolment < ApplicationRecord
  belongs_to :tutorial, optional: false
  belongs_to :project, optional: false

  has_one :tutorial_stream, through: :tutorial

  validates :tutorial, presence: true
  validates :project,  presence: true

  # Always add a unique index to the DB to prevent new records from passing the validations when checked at the same time before being written
  validates :tutorial, uniqueness: { :scope => :project, message: 'already exists for the selected student' }

  # Ensure only one tutorial stream per stream
  validate :ensure_only_one_tutorial_per_stream, on: :create

  # Ensure that student cannot enrol in tutorial of different units
  validate :unit_must_be_same

  # Ensure that student cannot enrol in tutorial of different campus
  validate :campus_must_be_same

  # If enrolled in tutorial with no stream, cannot enrol again
  validate :ensure_cannot_have_more_than_one_enrolment_when_tutorial_stream_is_null, on: :create

  # Only one tutorial enrolment per stream for each project
  validate :ensure_max_one_tutorial_enrolment_per_stream

  # Switch from stream to no stream is not allowed
  validate :ensure_cannot_enrol_in_tutorial_with_no_stream_when_enrolled_in_stream

  # Ensure in the same tutorial as a group if needed
  validate :validate_tutorial_change, if: :will_save_change_to_tutorial_id?

  # Ensure we check if we can leave the tutorial... and remove groups if needed
  before_destroy :remove_from_groups_on_destroy

  def unit_must_be_same
    if project.unit.present? and tutorial.unit.present? and not project.unit.eql? tutorial.unit
      errors.add(:project, 'and tutorial belong to different unit')
    end
  end

  def campus_must_be_same
    if project.campus.present? and tutorial.campus.present? and !project.campus.eql? tutorial.campus
      errors.add(:project, 'and tutorial belong to different campus')
    end
  end

  def ensure_cannot_have_more_than_one_enrolment_when_tutorial_stream_is_null
    if project.tutorial_enrolments
              .joins(:tutorial)
              .where("tutorials.tutorial_stream_id is null")
              .count > 0
      errors.add(:project, 'cannot have more than one enrolment when it is enrolled in tutorial with no stream')
    end
  end

  def ensure_max_one_tutorial_enrolment_per_stream
    # It is valid, unless there is a tutorial enrolment record in the DB that is for the same tutorial stream
    if project.tutorial_enrolments
              .joins(:tutorial)
              .where("(tutorials.tutorial_stream_id = :sid #{self.id.present? ? 'AND (tutorial_enrolments.id <> :id)' : ''})", sid: tutorial.tutorial_stream_id, id: self.id)
              .count > 0
      errors.add(:project, 'already enrolled in a tutorial with same tutorial stream')
    end
  end

  def ensure_cannot_enrol_in_tutorial_with_no_stream_when_enrolled_in_stream
    if project.tutorial_enrolments
              .joins(:tutorial)
              .where("tutorials.tutorial_stream_id is not null AND :tutorial_stream_id is null AND tutorial_enrolments.id <> :id", tutorial_stream_id: tutorial.tutorial_stream_id, id: id)
              .count > 0
      errors.add(:project, 'cannot enrol in tutorial with no stream when enrolled in stream')
    end
  end

  def ensure_only_one_tutorial_per_stream
    if project.tutorial_enrolments
              .joins(:tutorial)
              .where("tutorials.tutorial_stream_id = :sid OR (tutorials.tutorial_stream_id IS NULL AND :sid IS NULL)", sid: tutorial.tutorial_stream_id)
              .count > 0
      errors.add(:tutorial_stream, 'already exists for the selected student')
    end
  end

  def action_on_student_leave_tutorial(for_tutorial_id = nil)
    # If there are no groups then you can change the tutorial
    return :none_can_leave if project.groups.count == 0

    result = :none_can_leave

    # Now get the group
    project.groups.where(tutorial_id: for_tutorial_id || tutorial_id).find_each do |grp|
      # You can move if the tutorial allows it
      next unless grp.limit_members_to_tutorial?

      # Remove from the group if we can... otherwise this is an error!
      if grp.group_set.allow_students_to_manage_groups
        result = :leave_after_remove_from_group
      else
        # We have a group that cannot be left - the student cannot remove themselves and they must be in this tutorial
        return :leave_denied
      end
    end

    result
  end

  private

  # You can change the tutorial unless you are in a group that must be in this tutorial
  def validate_tutorial_change
    # If there is no change of tutorial id then you can change the tutorial
    return unless tutorial_id_change_to_be_saved

    # Get ids from change
    id_from = tutorial_id_change_to_be_saved[0]
    id_to = tutorial_id_change_to_be_saved[1]

    # If no real change... no problem
    return if id_from == id_to

    # What action needs to occur when the student leaves this tutorial?
    action = action_on_student_leave_tutorial(id_from)

    return if action == :none_can_leave

    if action == :leave_denied
      abbr = Tutorial.find(id_from).abbreviation
      errors.add(:groups, "require #{project.student.name} to be in tutorial #{abbr}")
    else # leave after remove from group
      project.groups.where(tutorial_id: id_from).find_each do |grp|
        # Skip groups that can be in other tutorials
        next unless grp.limit_members_to_tutorial?

        # Remove from the group if we can... otherwise this is an error!
        if grp.group_set.allow_students_to_manage_groups
          grp.remove_member(project)
        else
          errors.add(:groups, "require #{project.student.name} to be in tutorial #{grp.tutorial.abbreviation}")
        end
      end
    end
  end

  # Check group removal on delete
  def remove_from_groups_on_destroy
    project.groups.where(tutorial_id: tutorial_id).find_each do |grp|
      # Skip groups that can be in other tutorials
      next unless grp.limit_members_to_tutorial?

      # Remove from the group if we can... otherwise this is an error!
      if grp.group_set.allow_students_to_manage_groups
        grp.remove_member(project)
      else
        errors.add(:groups, "require #{project.student.name} to be in tutorial #{grp.tutorial.abbreviation}")
        throw :abort
      end
    end
  end
end
