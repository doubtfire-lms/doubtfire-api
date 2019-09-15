require 'test_helper'

class GroupTest < ActiveSupport::TestCase
def test_add_duplicate_group_name 
  u = Unit.first
	tutorial = unit.tutorials.first

    group_set_params = {
      name: 'Group Work',
      allow_students_to_create_groups: true,
      allow_students_to_manage_groups: true,
      keep_groups_in_same_class: true
    }

    group_set = GroupSet.create!(group_set_params)
    group_set.unit = u	
    group_set.save! 
	
  	last = group_set.groups.last
  	num = last.nil? ? 1 : last.number + 1

  	group_params = {
        name: 'Group1',  
        number: num
      }
    
    group1 = Group.create!(group_params)
    group1.group_set = group_set	
  	group1.tutorial = tutorial	
    group1.save! 
  	
  	group_params = {
        name: 'Group1',  
        number: num + 1
      }
  	
  	group2 = Group.create!(group_params) 
    group2.group_set = group_set	
  	group2.tutorial = tutorial	
    group2.save! 
  	
  	assert_equal 1, group_set.errors.count
end