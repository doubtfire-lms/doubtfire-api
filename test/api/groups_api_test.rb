require 'test_helper'

class GroupsApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::TestFileHelper

  def app
    Rails.application
  end

#   def test_get_groups
#     # The GET we are testing
#     unit_id = rand(1..Unit.all.length)

#   end

  def test_group_submission_with_extensions
    unit = FactoryBot.create :unit

    group_set = GroupSet.create!({name: 'test_group_submission_with_extensions', unit: unit})
    group_set.save!

    group = Group.create!({group_set: group_set, name: 'test_group_submission_with_extensions', tutorial: unit.tutorials.first})

    group.add_member(unit.active_projects[0])
    group.add_member(unit.active_projects[1])
    group.add_member(unit.active_projects[2])

    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Task to switch from ind to group after submission',
        description: 'test def',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 1.week,
        target_date: Time.zone.now - 1.day,
        due_date: Time.zone.now + 1.week,
        abbreviation: 'TaskSwitchIndGrp',
        restrict_status_updates: false,
        upload_requirements: [ { "key" => 'file0', "name" => 'Shape Class', "type" => 'code' } ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0,
        group_set: group_set
      })
    assert td.save!

    data_to_post = {
      comment: 'I need more time',
      weeks_requested: 2
    }

    project = group.projects.first
    tutor = project.tutor_for(td)

    # Add username and auth_token to Header
    add_auth_header_for(user: project.student)

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", data_to_post
    comment_id = last_response_body["id"]
    assert_equal 201, last_response.status, last_response_body

    comment = TaskComment.find(comment_id)
    comment.assess_extension(tutor, true)

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    data_to_post = with_file('test_files/submissions/test.sql', 'text/plain', data_to_post)

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post
    assert_equal 201, last_response.status

    group.reload
    group.projects.each do |proj|
        task = proj.task_for_task_definition(td)
        assert_equal TaskStatus.ready_for_feedback, task.task_status
    end

    # ensure groupset has groups to destroy
    group_set.reload

    td.destroy
    group_set.destroy
  end

  def test_comment_on_group_task_without_group
    unit = FactoryBot.create :unit

    group_set = GroupSet.create!({name: 'test_comment_without_group', unit: unit})
    group_set.save!

    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Task to switch from ind to group after submission',
        description: 'test def',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 1.week,
        target_date: Time.zone.now - 1.day,
        due_date: Time.zone.now + 1.week,
        abbreviation: 'TaskSwitchIndGrp',
        restrict_status_updates: false,
        upload_requirements: [ { "key" => 'file0', "name" => 'Shape Class', "type" => 'code' } ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0,
        group_set: group_set
      })
    assert td.save!

    project = unit.projects.first

    comment_data = { comment: "Hello World" }

     # Add username and auth_token to Header
    add_auth_header_for(user: project.student)

    post_json "/api/projects/#{project.id}/task_def_id/#{td.id}/comments", comment_data

    assert_equal 201, last_response.status

    td.destroy
    group_set.destroy
  end

  def test_pdf_comment_on_group_task
    unit = FactoryBot.create :unit

    group_set = GroupSet.create!({name: 'test_comment_without_group', unit: unit})
    group_set.save!

    group = Group.create!({group_set: group_set, name: 'test_group_submission_with_extensions', tutorial: unit.tutorials.first})

    group.add_member(unit.active_projects[0])
    group.add_member(unit.active_projects[1])
    group.add_member(unit.active_projects[2])

    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Task to switch from ind to group after submission',
        description: 'test def',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 1.week,
        target_date: Time.zone.now - 1.day,
        due_date: Time.zone.now + 1.week,
        abbreviation: 'TaskSwitchIndGrp',
        restrict_status_updates: false,
        upload_requirements: [ { "key" => 'file0', "name" => 'Shape Class', "type" => 'code' } ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0,
        group_set: group_set
      })
    assert td.save!

    project = unit.projects.first

    comment_data = { attachment: upload_file('test_files/submissions/00_question.pdf', 'application/pdf') }

    # Add username and auth_token to Header
    add_auth_header_for(user: project.student)

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/comments", comment_data

    assert_equal 201, last_response.status
    assert File.exist?(TaskComment.last.attachment_path)

    td.destroy
    group.destroy
    group_set.destroy
  end

  def test_pdf_comment_on_group_task_without_group
    unit = FactoryBot.create :unit

    group_set = GroupSet.create!({name: 'test_comment_without_group', unit: unit})
    group_set.save!

    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Task to switch from ind to group after submission',
        description: 'test def',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 1.week,
        target_date: Time.zone.now - 1.day,
        due_date: Time.zone.now + 1.week,
        abbreviation: 'TaskSwitchIndGrp',
        restrict_status_updates: false,
        upload_requirements: [ { "key" => 'file0', "name" => 'Shape Class', "type" => 'code' } ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0,
        group_set: group_set
      })
    assert td.save!

    project = unit.projects.first

    comment_data = { attachment: upload_file('test_files/submissions/00_question.pdf', 'application/pdf') }

    # Add username and auth_token to Header
    add_auth_header_for(user: project.student)

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/comments", comment_data

    assert_equal 201, last_response.status

    td.destroy
    group_set.destroy
  end

  def test_create_group
    unit = FactoryBot.create :unit

    gs_data = {
      group_set: {
        name: 'GroupSet Name',
        allow_students_to_create_groups: false,
        allow_students_to_manage_groups: true,
        keep_groups_in_same_class: false,
        capacity: 2
      }
    }

    group_data = {
      group: {
        name: 'Group 1',
        tutorial_id: unit.tutorials.first.id
      }
    }

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    # Create group set
    post "/api/units/#{unit.id}/group_sets", gs_data
    assert_equal 201, last_response.status, last_response_body
    gs_response = last_response_body
    assert_equal 1, unit.group_sets.count

    # Create group
    post "/api/units/#{unit.id}/group_sets/#{gs_response['id']}/groups", group_data
    assert_equal 201, last_response.status, last_response_body
    group_response = last_response_body
    assert_equal 1, unit.group_sets.first.groups.count

    # Add a group member (the student does it...)
    project = unit.active_projects.first

    # Add username and auth_token to Header
    add_auth_header_for(user: project.student)

    post "/api/units/#{unit.id}/group_sets/#{gs_response['id']}/groups/#{group_response['id']}/members/#{project.id}"

    assert_equal 201, last_response.status
    assert_equal 1, unit.group_sets.first.groups.first.group_memberships.count

    # Add another group member (the student does it...)
    project = unit.active_projects.second

    # Add username and auth_token to Header
    add_auth_header_for(user: project.student)

    post "/api/units/#{unit.id}/group_sets/#{gs_response['id']}/groups/#{group_response['id']}/members/#{project.id}"

    assert_equal 201, last_response.status, last_response_body
    assert_equal 2, unit.group_sets.first.groups.first.group_memberships.count

    # Exceed capacity (the student does it...)
    project = unit.active_projects.last

    post "/api/units/#{unit.id}/group_sets/#{gs_response['id']}/groups/#{group_response['id']}/members/#{project.id}"

    assert_equal 403, last_response.status, last_response_body
    assert_equal 2, unit.group_sets.first.groups.first.group_memberships.count

    # Try again as tutor
    tutor = FactoryBot.create(:user, :tutor)
    unit.employ_staff tutor, Role.tutor

    # Add username and auth_token to Header
    add_auth_header_for(user: tutor)

    post "/api/units/#{unit.id}/group_sets/#{gs_response['id']}/groups/#{group_response['id']}/members/#{project.id}"

    assert_equal 403, last_response.status, last_response_body
    assert_equal 2, unit.group_sets.first.groups.first.group_memberships.count

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    # Try again as convenor
    post "/api/units/#{unit.id}/group_sets/#{gs_response['id']}/groups/#{group_response['id']}/members/#{project.id}"

    assert_equal 201, last_response.status, last_response_body
    assert_equal 3, unit.group_sets.first.groups.first.group_memberships.count
  end

  def test_group_student_count
    unit = FactoryBot.create :unit, group_sets: 1, groups: [{ gs: 0, students: 2}]
    assert_equal 2, unit.groups.first.group_memberships.count

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    # Get the groups for the first group set
    get "/api/units/#{unit.id}/group_sets/#{unit.group_sets.first.id}/groups"
    assert_equal 200, last_response.status
    assert_equal 2, last_response_body.first['student_count'], last_response_body
  end

  def test_group_switch_tutorial
    unit = FactoryBot.create :unit, group_sets: 1, groups: [{gs: 0, students: 0}]

    gs = unit.group_sets.first
    gs.update keep_groups_in_same_class: true, allow_students_to_manage_groups: true
    group1 = gs.groups.first

    p1 = group1.tutorial.projects.first
    p2 = group1.tutorial.projects.last

    group1.add_member p1
    group1.add_member p2

    tutorial = FactoryBot.create :tutorial, unit: unit, campus: nil

    refute p1.enrolled_in? tutorial
    refute p2.enrolled_in? tutorial

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    put "/api/units/#{unit.id}/group_sets/#{gs.id}/groups/#{group1.id}", { group: {tutorial_id: tutorial.id} }

    assert 201, last_response.status

    p1.reload
    p2.reload

    assert p1.valid?
    assert p2.valid?

    assert p1.enrolled_in? tutorial
    assert p2.enrolled_in? tutorial
  end

  def test_group_switch_tutorial_no_student_management
    unit = FactoryBot.create :unit, group_sets: 1, groups: [{gs: 0, students: 0}]

    gs = unit.group_sets.first
    gs.update keep_groups_in_same_class: true, allow_students_to_manage_groups: false
    group1 = gs.groups.first

    p1 = group1.tutorial.projects.first
    p2 = group1.tutorial.projects.last

    group1.add_member p1
    group1.add_member p2

    tutorial = FactoryBot.create :tutorial, unit: unit, campus: nil

    refute p1.enrolled_in? tutorial
    refute p2.enrolled_in? tutorial

    add_auth_header_for(user: unit.main_convenor_user)
    put "/api/units/#{unit.id}/group_sets/#{gs.id}/groups/#{group1.id}", { group: {tutorial_id: tutorial.id} }

    assert 201, last_response.status

    p1.reload
    p2.reload

    assert p1.valid?
    assert p2.valid?

    assert p1.enrolled_in? tutorial
    assert p2.enrolled_in? tutorial
  end

  def test_group_switch_tutorial_unenrolled_students
    unit = FactoryBot.create :unit, group_sets: 1, groups: [{gs: 0, students: 0}]

    gs = unit.group_sets.first
    gs.update keep_groups_in_same_class: true, allow_students_to_manage_groups: false, capacity: 2
    group1 = gs.groups.first

    p1 = group1.tutorial.projects.first
    p2 = group1.tutorial.projects.last

    group1.add_member p1
    group1.add_member p2

    assert group1.at_capacity?

    tutorial = FactoryBot.create :tutorial, unit: unit, campus: nil

    refute p1.enrolled_in? tutorial
    refute p2.enrolled_in? tutorial

    p2.update(enrolled: false)
    p2.reload

    refute group1.at_capacity?

    add_auth_header_for(user: unit.main_convenor_user)
    put "/api/units/#{unit.id}/group_sets/#{gs.id}/groups/#{group1.id}", { group: {tutorial_id: tutorial.id} }

    assert 201, last_response.status

    group1.reload

    p1.reload
    p2.reload

    assert p1.valid?
    assert p2.valid?

    assert group1.valid?, group1.errors.full_messages

    assert p1.enrolled_in? tutorial
    refute p2.enrolled_in? tutorial

    # check we can reenrol the student
    refute group1.at_capacity?
    assert p2.update(enrolled: true)
    refute group1.at_capacity? # they are not in the right tutorial
    assert_equal 1, group1.projects.count
  end

  def test_locked_groups
    unit = FactoryBot.create :unit, group_sets: 1, groups: [{gs: 0, students: 0}], task_count: 0

    gs = unit.group_sets.first
    group1 = gs.groups.first

    p1 = group1.tutorial.projects.first
    p2 = group1.tutorial.projects.last

    group1.add_member p1
    group1.add_member p2

    group1.update(locked: true)

    add_auth_header_for(user: p1.user)
    delete "/api/units/#{unit.id}/group_sets/#{gs.id}/groups/#{group1.id}/members/#{p1.id}"

    assert_equal 403, last_response.status

    post "/api/units/#{unit.id}/group_sets/#{gs.id}/groups/#{group1.id}/members/#{unit.active_projects.last.id}"
    assert_equal 403, last_response.status
  end
end
