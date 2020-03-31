#
# Records which students are in this group... used to determine the related students on submission
#
class GroupMembership < ActiveRecord::Base
  include LogHelper

  belongs_to :group
  belongs_to :project
  has_one :group_set, through: :group

  validate :must_be_in_same_tutorial, if: :restricted_to_tutorial?

  def restricted_to_tutorial?
    active && group_set.keep_groups_in_same_class
  end

  def must_be_in_same_tutorial
    if active && !in_group_tutorial?(group.tutorial)
      errors.add(:group, "requires all students to be in the #{group.tutorial.abbreviation} tutorial")
    end
  end

  def in_group_tutorial?(tutorial)
    project.enrolled_in? tutorial
  end
end
