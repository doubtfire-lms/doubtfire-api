require 'test_helper'

class FeedbackTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_get_awaiting_feedback
    unit = FactoryBot.create(:unit, perform_submissions: true, unenrolled_student_count: 0, part_enrolled_student_count: 0)

    unit.teaching_staff.each do |user|
      expected_response_ids = unit.tasks_awaiting_feedback(user).map { |data| data['id'] }

      # Add auth_token and username to header
      add_auth_header_for(user: user)

      get "/api/units/#{unit.id}/feedback"

      assert_equal 200, last_response.status

      assert_equal expected_response_ids.count, last_response_body.count

      # check each is the same
      last_response_body.each do |response|
        assert_includes expected_response_ids, response['id']
      end
    end
    unit.destroy
  end

  def test_tasks_for_task_inbox
    unit = FactoryBot.create(:unit, perform_submissions: true, unenrolled_student_count: 0, part_enrolled_student_count: 0, tutorials: 2, staff_count: 2, student_count: 2, task_count: 0)

    td1 = TaskDefinition.create!({
                                   unit_id: unit.id,
                                   tutorial_stream: unit.tutorial_streams.first,
                                   name: 'Code task',
                                   description: 'Code task',
                                   weighting: 4,
                                   target_grade: 0,
                                   start_date: Time.zone.now - 2.weeks,
                                   target_date: Time.zone.now + 1.week,
                                   abbreviation: 'CodeTask',
                                   restrict_status_updates: false,
                                   upload_requirements: [{ "key" => 'file0', "name" => 'Shape Class', "type" => 'code' }],
                                   plagiarism_warn_pct: 0.8,
                                   is_graded: true,
                                   max_quality_pts: 0
                                 })

    td2 = TaskDefinition.create!({
                                   unit_id: unit.id,
                                   tutorial_stream: unit.tutorial_streams.first,
                                   name: 'Code task2',
                                   description: 'Code task2',
                                   weighting: 4,
                                   target_grade: 0,
                                   start_date: Time.zone.now - 2.weeks,
                                   target_date: Time.zone.now + 1.week,
                                   abbreviation: 'CodeTask2',
                                   restrict_status_updates: false,
                                   upload_requirements: [{ "key" => 'file0', "name" => 'Shape Class', "type" => 'code' }],
                                   plagiarism_warn_pct: 0.8,
                                   is_graded: true,
                                   max_quality_pts: 0
                                 })

    student1 = unit.active_projects.first
    student2 = unit.active_projects.second
    tutor1 = unit.tutors.first
    tutor2 = unit.tutors.second

    tutorial1 = unit.tutorials.first
    tutorial2 = unit.tutorials.second

    assert_not_nil student1
    assert_not_nil student2
    assert_not_nil tutor1
    assert_not_nil tutor2
    assert_not_nil tutorial1
    assert_not_nil tutorial2

    unit.employ_staff(tutor1, Role.tutor)
    unit.employ_staff(tutor2, Role.tutor)

    tutorial1.assign_tutor(tutor1)
    tutorial2.assign_tutor(tutor2)

    student1.enrol_in(tutorial1)
    student2.enrol_in(tutorial2)

    # Submit tasks ready for feedback
    student1_task1 = student1.task_for_task_definition(td1)
    student2_task1 = student2.task_for_task_definition(td1)
    DatabasePopulator.assess_task(student1, student1_task1, tutor1, TaskStatus.ready_for_feedback, Time.zone.now)
    DatabasePopulator.assess_task(student2, student2_task1, tutor2, TaskStatus.ready_for_feedback, Time.zone.now)

    # Add comments to unsubmitted task
    student1_task2 = student1.task_for_task_definition(td2)
    student2_task2 = student2.task_for_task_definition(td2)
    comment1 = student1_task2.add_text_comment(student1.user, "Test 1")
    comment2 = student2_task2.add_text_comment(student2.user, "Test 1")
    assert_not_nil comment1
    assert_not_nil comment2

    [tutor1, tutor2].each do |user|
      # Add auth_token and username to header
      add_auth_header_for(user: user)

      # Defaults inbox?my_students_only = false
      get "/api/units/#{unit.id}/tasks/inbox"

      # 2 submissions ready for feedback + 2 tasks with unread comments = 4 total
      assert_equal 200, last_response.status, last_response_body
      assert_equal 4, last_response_body.count, last_response_body

      # check each is the same
      expected_response = unit.tasks_for_task_inbox(user)
      last_response_body.zip(expected_response).each do |response, expected|
        assert_json_matches_model expected, response, ['id']
      end

      get "/api/units/#{unit.id}/tasks/inbox?my_students_only=true"

      # 1 submission ready for feedback + 1 task with unread comments = 2 total
      assert_equal 200, last_response.status, last_response_body
      assert_equal 2, last_response_body.count, last_response_body

      # check each is the same
      expected_response2 = unit.tasks_for_task_inbox(user, true)
      last_response_body.zip(expected_response2).each do |response, expected|
        assert_json_matches_model expected, response, ['id']
      end

      # Test task explorer
      get "/api/units/#{unit.id}/task_definitions/#{unit.task_definitions.first.id}/tasks"

      assert_equal 200, last_response.status
      assert_equal unit.task_definitions.first.tasks.where("task_status_id > 1").count, last_response_body.count, last_response_body
    end
    unit.destroy
  end

  def test_task_similarity_inbox
    unit = FactoryBot.create(:unit, perform_submissions: true, unenrolled_student_count: 0, part_enrolled_student_count: 0, tutorials: 2, staff_count: 2)

    expected_count = 0
    user = unit.main_convenor_user

    # Add auth_token and username to header
    add_auth_header_for(user: user)

    task = unit.tasks.last

    get "/api/tasks/#{task.id}/similarities"

    assert_equal 200, last_response.status

    assert_equal expected_count, last_response_body.count, last_response_body

    MossTaskSimilarity.create! do |pml|
      pml.task = task
      pml.pct = 50
      pml.plagiarism_report_url = 'test'
      pml.flagged = true
      pml.other_task = task
    end

    expected_count = 1
    get "/api/tasks/#{task.id}/similarities"

    assert_equal 200, last_response.status

    assert_equal expected_count, last_response_body.count, last_response_body

    unit.destroy
  end
end
