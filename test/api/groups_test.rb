require 'test_helper'

class GroupsTest < ActiveSupport::TestCase
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
    unit = Unit.first

    group_set = GroupSet.create!({name: 'test_group_submission_with_extensions', unit: unit})
    group_set.save!

    group = Group.create!({group_set: group_set, name: 'test_group_submission_with_extensions', tutorial: unit.tutorials.first, number: 0})

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
      trigger: 'ready_to_mark'
    }

    data_to_post = with_file('test_files/submissions/test.sql', 'text/plain', data_to_post)

    project = group.projects.first

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", with_auth_token({comment: 'I need time!', weeks_requested: 1}, project.student)
    comment_id = last_response_body["id"]
    assert_equal 201, last_response.status

    comment = TaskComment.find(comment_id)
    comment.assess_extension(project.main_tutor, true)

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
    unit = Unit.first

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
    unit = Unit.first

    group_set = GroupSet.create!({name: 'test_comment_without_group', unit: unit})
    group_set.save!

    group = Group.create!({group_set: group_set, name: 'test_group_submission_with_extensions', tutorial: unit.tutorials.first, number: 0})

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

    comment_data = { attachment: Rack::Test::UploadedFile.new('test_files/submissions/00_question.pdf', 'application/pdf') }

    post with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/comments", project.student), comment_data

    assert_equal 201, last_response.status
    assert File.exists?(TaskComment.last.attachment_path)

    td.destroy
    group.destroy
    group_set.destroy
  end

  def test_pdf_comment_on_group_task_without_group
    unit = Unit.first

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

    comment_data = { attachment: Rack::Test::UploadedFile.new('test_files/submissions/00_question.pdf', 'application/pdf') }

    post with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/comments", project.student), comment_data

    assert_equal 201, last_response.status

    td.destroy
    group_set.destroy
  end


end
