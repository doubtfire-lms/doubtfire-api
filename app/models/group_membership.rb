#
# Records which students are in this group... used to determine the related students on submission
#
class GroupMembership < ActiveRecord::Base
  belongs_to :group
  belongs_to :project
  has_one :group_set, through: :group

  validate :must_be_in_same_tutorial, if: :restricted_to_tutorial? 

  def restricted_to_tutorial?
    # puts "#{active} #{group_set.keep_groups_in_same_class}"
    self.active && group_set.keep_groups_in_same_class
  end

  def must_be_in_same_tutorial
    # puts "checking #{project.id} ... #{project.tutorial.id} == #{group.tutorial.id}"
    if active && ! in_group_tutorial?
      errors.add(:group, "requires all students to be in the #{group.tutorial.abbreviation} tutorial")
    end
  end

  def in_group_tutorial?
    project.tutorial == group.tutorial
  end
  
end
