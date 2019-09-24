require 'test_helper'

class GroupTest < ActiveSupport::TestCase

setup do
  @unit = Unit.first
  @group_set_params = {
      name: 'Group Work',
      allow_students_to_create_groups: true,
      allow_students_to_manage_groups: true,
      keep_groups_in_same_class: true
    }   
  end

def test_add_members_to_group 

   group_set = GroupSet.create!(@group_set_params)
   group_set.unit = @unit
   group_set.save! 
  
   last = group_set.groups.last
   num = last.nil? ? 1 : last.number + 1
   tutorial = @unit.tutorials.first

    group_params = {
         name: 'Group1',  
         number: num,
         group_set: group_set,
         tutorial: tutorial  
    } 

   group = Group.create!(group_params)   
   group.save! 
   student_1 = @unit.projects.find(1)
   student_2 = @unit.projects.find(2)
   student_3 = @unit.projects.find(3)

   group.add_member(student_1)
   group.add_member(student_2)   
   
   #add duplicate member
   group.add_member(student_1)
   assert_equal group.add_member(student_1), group.group_memberships.where('project_id = :project_id', project_id: 1).first

   #test remove  member
   group.add_member(student_3)
   group.remove_member(student_3)
   assert_equal group.group_memberships.where('project_id = :project_id', project_id: 3).first.active, false
   assert_equal group.has_active_group_members?, true
  end

  def test_check_permissions
    assert_equal Group.permissions[:convenor].count, 2
    assert_equal Group.permissions[:tutor].count, 2
    assert_equal Group.permissions[:student].count, 1
    assert_equal Group.permissions[:nil].count, 0   
   end 

  def test_ensure_no_submissions
 
    group_set = GroupSet.create!(@group_set_params)
    group_set.unit = @unit
    group_set.save! 
  
    last = group_set.groups.last
    num = last.nil? ? 1 : last.number + 1
    tutorial = @unit.tutorials.first

    group_params = {
         name: 'Group1',  
         number: num,
         group_set: group_set,
         tutorial: tutorial  
    } 
    
   group = Group.create!(group_params)   
   group.save!    

   student_1 = @unit.projects.find(1)   
   student_2 = @unit.projects.find(2)
   student_3 = @unit.projects.find(3)
   student_4 = @unit.projects.find(24)

   group.add_member(student_1)
   group.add_member(student_2)
   group.add_member(student_3)

   #test all members in the same tutorial
   assert_raise ActiveRecord::RecordInvalid do
    group.add_member(student_4)
   end    

   td = TaskDefinition.new({
      unit_id: @unit.id,
      name: 'Test quality points',
      description: 'test def',
      weighting: 4,
      target_grade: 0,
      start_date: @unit.start_date - 2.week,
      target_date: @unit.start_date - 1.weeks,
      abbreviation: 'TestQualPts',
      restrict_status_updates: false,
      upload_requirements: [ ],
      plagiarism_warn_pct: 0.8,
      is_graded: false,
      max_quality_pts: 5
    })
    td.save!

  td.group_set = group_set
  td.save!
  task = student_1.task_for_task_definition(td)

  contributors = group.projects.map { |proj| { project: proj, pct: 33 } }   
  gs = group.create_submission task, '', group.projects.map { |proj| { project: proj, pct: 100 / group.projects.count } }
  assert_equal group.ensure_no_submissions,false

  user1 = User.find(student_1.user_id)  
  #user1.role = Role.student
  user1.save!
  assert_equal group.role_for(user1), Role.student   
  assert_equal group.has_user(user1),true    

  # test allow_students_to_manage_groups
  assert_equal group.specific_permission_hash(:student,Group.permissions,nil),  [:get_members, :manage_group] 

  # test insufficient
  gs.destroy 

  contributors = group.projects.map { |proj| { project: proj, pct: 80 / group.projects.count } }  

  assert_raise 'Contribution percentages are insufficient.' do
      group.create_submission task, '', contributors
  end
  
  # test excessive
  contributors = group.projects.map { |proj| { project: proj, pct: 120 / group.projects.count } }  
  assert_raise 'Contribution percentages are excessive.' do
      group.create_submission task, '', contributors
  end

 #test negative pct 
contributors = group.projects.map { |proj| { project: proj, pct: 90 / group.projects.count } }  
contributors.first[:pct] = -1
assert_raise 'Contribution percentages are insufficient.' do
      group.create_submission task, '', contributors
end

contributors = group.projects.map { |proj| { project: proj, pct: 100 / group.projects.count } }  
gs = group.create_submission task, '', contributors

#test reload 
contributors = group.projects.map { |proj| { project: proj, pct: 90 / group.projects.count } }  
gs1 = group.create_submission task, '', contributors
  end
end