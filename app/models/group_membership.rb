#
# Records which students are in this group... used to determine the related students on submission
#
class GroupMembership < ApplicationRecord

  belongs_to :group, optional: false
  belongs_to :project, optional: false
  has_one :group_set, through: :group

  validate :must_be_in_same_tutorial, if: :restricted_to_tutorial?

  def restricted_to_tutorial?
    project.enrolled && active && group_set.keep_groups_in_same_class
  end

  def must_be_in_same_tutorial
    if project.enrolled && active && !in_group_tutorial?(group.tutorial)
      errors.add(:group, "requires all students to be in the #{group.tutorial.abbreviation} tutorial which is not the case for #{project.student.name}.")
    end
  end

  def in_group_tutorial?(tutorial)
    project.enrolled_in? tutorial
  end
end
