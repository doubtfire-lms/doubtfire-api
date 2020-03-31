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

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", with_auth_token(data_to_post, project.student)
    comment_id = last_response_body["id"]
    assert_equal 201, last_response.status, last_response_body

    comment = TaskComment.find(comment_id)
    comment.assess_extension(tutor, true)

    data_to_post = {
      trigger: 'ready_to_mark'
    }

    data_to_post = with_file('test_files/submissions/test.sql', 'text/plain', data_to_post)

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", with_auth_token(data_to_post, project.student)
    assert_equal 201, last_response.status

    group.reload
    group.projects.each do |proj|
        task = proj.task_for_task_definition(td)
        assert_equal TaskStatus.ready_to_mark, task.task_status
    end

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

    post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/comments", project.student), comment_data

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

    post with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/comments", project.student), comment_data

    assert_equal 201, last_response.status
    assert File.exists?(TaskComment.last.attachment_path)

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

    post with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/comments", project.student), comment_data

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

    # Create group set
    post with_auth_token("/api/units/#{unit.id}/group_sets", unit.main_convenor_user), gs_data
    assert_equal 201, last_response.status, last_response_body
    gs_response = last_response_body
    assert_equal 1, unit.group_sets.count

    # Create group
    post with_auth_token("/api/units/#{unit.id}/group_sets/#{gs_response['id']}/groups", unit.main_convenor_user), group_data
    assert_equal 201, last_response.status, last_response_body
    group_response = last_response_body
    assert_equal 1, unit.group_sets.first.groups.count

    # Add a group member (the student does it...)
    project = unit.active_projects.first

    post with_auth_token("/api/units/#{unit.id}/group_sets/#{gs_response['id']}/groups/#{group_response['id']}/members", project.student), {project_id: project.id}

    assert_equal 201, last_response.status
    assert_equal 1, unit.group_sets.first.groups.first.group_memberships.count

    # Add another group member (the student does it...)
    project = unit.active_projects.second

    post with_auth_token("/api/units/#{unit.id}/group_sets/#{gs_response['id']}/groups/#{group_response['id']}/members", project.student), {project_id: project.id}

    assert_equal 201, last_response.status, last_response_body
    assert_equal 2, unit.group_sets.first.groups.first.group_memberships.count

    # Exceed capacity (the student does it...)
    project = unit.active_projects.last

    post with_auth_token("/api/units/#{unit.id}/group_sets/#{gs_response['id']}/groups/#{group_response['id']}/members", project.student), {project_id: project.id}

    assert_equal 403, last_response.status, last_response_body
    assert_equal 2, unit.group_sets.first.groups.first.group_memberships.count

    # Try again as tutor
    tutor = FactoryBot.create(:user, :tutor)
    unit.employ_staff tutor, Role.tutor

    post with_auth_token("/api/units/#{unit.id}/group_sets/#{gs_response['id']}/groups/#{group_response['id']}/members", tutor), {project_id: project.id}

    assert_equal 403, last_response.status, last_response_body
    assert_equal 2, unit.group_sets.first.groups.first.group_memberships.count
    
    # Try again as convenor
    post with_auth_token("/api/units/#{unit.id}/group_sets/#{gs_response['id']}/groups/#{group_response['id']}/members", unit.main_convenor_user), {project_id: project.id}

    assert_equal 201, last_response.status, last_response_body
    assert_equal 3, unit.group_sets.first.groups.first.group_memberships.count
  end

  def test_group_student_count
    unit = FactoryBot.create :unit, group_sets: 1, groups: [{ gs: 0, students: 2}]
    assert_equal 2, unit.groups.first.group_memberships.count

    # Get the groups for the first group set
    get with_auth_token("/api/units/#{unit.id}/group_sets/#{unit.group_sets.first.id}/groups", unit.main_convenor_user)
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
    
    put "/api/units/#{unit.id}/group_sets/#{gs.id}/groups/#{group1.id}", with_auth_token({ group: {tutorial_id: tutorial.id} }, unit.main_convenor_user)
    
    assert 201, last_response.status

    p1.reload
    p2.reload

    assert p1.enrolled_in? tutorial
    assert p2.enrolled_in? tutorial

  end


end
