require 'test_helper'

class TaskTurnaroundApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include ActiveSupport::Testing::TimeHelpers

  def app
    Rails.application
  end

  def setup
    @unit = FactoryBot.create(:unit)
    @task = FactoryBot.create(:task, project: FactoryBot.create(:project, unit: @unit))
    @convenor = FactoryBot.create(:user, :convenor)
    @unit.employ_staff(@convenor, Role.convenor)
    @start = Time.find_zone!('Australia/Sydney').local(2026, 11, 16)
    @path = "/api/units/#{@unit.id}/task_turnaround"
    add_auth_header_for(user: @convenor)
  end

  def assessment(submitted, assessed)
    @task.task_submissions.create!(submission_time: submitted, assessment_time: assessed, assessor: @convenor)
  end

  def test_corrections_resubmissions_and_observed_marking_coverage
    submitted = @start + 9.hours
    assessment(submitted, submitted + 2.hours)
    assessment(submitted, submitted + 125.minutes)
    assessment(submitted + 3.weeks, submitted + 3.weeks + 45.minutes)

    session = FactoryBot.create(:marking_session, unit: @unit, user: @convenor,
                                start_time: submitted + 110.minutes, end_time: submitted + 125.minutes)
    [[110, 'get-submission-details'], [112, 'get-submission-details'], [120, 'assessing'],
     [122, 'get-submission-details'], [125, 'assessing']].each do |minutes, action|
      session.session_activities.create!(task: @task, action: action, created_at: submitted + minutes.minutes)
    end

    get @path
    assert_equal 200, last_response.status
    report = JSON.parse(last_response.body)
    row = report.fetch('task_definitions').find { |definition| definition['task_definition_id'] == @task.task_definition_id }
    assert_equal({ 'average_seconds' => 5100, 'assessed_attempt_count' => 2 }, row['feedback_wait'])
    assert_equal({ 'average_seconds' => 780, 'measured_attempt_count' => 1 }, row['estimated_marking_time'])
  end

  def test_includes_later_corrections_and_excludes_assessment_only_attempts
    assessment(@start, @start + 1.day)
    assessment(@start, @start + 7.days)
    assessment(@start + 2.days, @start + 2.days)
    assessment(@start + 2.days, @start + 3.days)
    get @path
    assert_equal 200, last_response.status
    row = JSON.parse(last_response.body).fetch('task_definitions').find { |definition| definition['task_definition_id'] == @task.task_definition_id }
    assert_equal({ 'average_seconds' => 7.days.to_i, 'assessed_attempt_count' => 1 }, row['feedback_wait'])
    assert_equal({ 'average_seconds' => nil, 'measured_attempt_count' => 0 }, row['estimated_marking_time'])
  end

  def test_one_group_review_with_a_corrected_status_counts_once_for_five_members
    group_set = FactoryBot.create(:group_set, unit: @unit)
    group = FactoryBot.create(:group, group_set: group_set)
    definition = FactoryBot.create(:task_definition, unit: @unit, group_set: group_set)
    members = @unit.active_projects.limit(5).to_a
    assert_equal 5, members.size
    members.each { |project| group.add_member(project) }
    submitter_task = members.first.task_for_task_definition(definition)
    viewed_task = members.last.task_for_task_definition(definition)
    submitted_at = @unit.start_date.in_time_zone.beginning_of_day + 1.hour
    submitter_task.ensured_group_submission

    travel_to(submitted_at) do
      assert submitter_task.trigger_transition(trigger: 'ready_for_feedback', by_user: members.first.user)
    end
    # The tutor opened another member's copy of the same group submission.
    viewed_task.reload
    travel_to(submitted_at + 1.hour) do
      assert viewed_task.trigger_transition(trigger: 'discuss', by_user: @convenor)
    end
    travel_to(submitted_at + 65.minutes) do
      viewed_task.add_text_comment(@convenor, 'Please revise the explanation and resubmit.')
      assert viewed_task.trigger_transition(trigger: 'fix_and_resubmit', by_user: @convenor, check_feedback: true)
    end
    copies = submitter_task.reload.group_submission.tasks
    assert_equal 5, copies.where(task_status: TaskStatus.fix_and_resubmit).count
    assert_equal 10, TaskSubmission.where(task: copies, assessor: @convenor).count

    session = FactoryBot.create(:marking_session, unit: @unit, user: @convenor,
                                start_time: submitted_at + 50.minutes, end_time: submitted_at + 65.minutes)
    [[50, 'get-submission-details'], [60, 'assessing'], [65, 'assessing']].each do |minutes, action|
      session.session_activities.create!(task: viewed_task, action: action, created_at: submitted_at + minutes.minutes)
    end

    get @path
    assert_equal 200, last_response.status
    row = JSON.parse(last_response.body).fetch('task_definitions').find { |item| item['task_definition_id'] == definition.id }
    assert_equal({ 'average_seconds' => 3900, 'assessed_attempt_count' => 1 }, row['feedback_wait'])
    assert_equal({ 'average_seconds' => 600, 'measured_attempt_count' => 1 }, row['estimated_marking_time'])

    # A second submission from this group contributes one more review.
    resubmitted_at = submitted_at + 1.day
    travel_to(resubmitted_at) do
      assert submitter_task.reload.trigger_transition(trigger: 'ready_for_feedback', by_user: members.first.user)
    end
    travel_to(resubmitted_at + 20.minutes) do
      assert viewed_task.reload.trigger_transition(trigger: 'discuss', by_user: @convenor)
    end
    log_session([[16, viewed_task, 'get-submission-details'], [20, viewed_task, 'assessing']], start_at: resubmitted_at)
    row = report_by_definition.fetch(definition.id)
    assert_equal({ 'average_seconds' => 2550, 'assessed_attempt_count' => 2 }, row['feedback_wait'])
    assert_equal({ 'average_seconds' => 420, 'measured_attempt_count' => 2 }, row['estimated_marking_time'])
  end

  def test_tutors_cannot_request_unit_wide_report
    tutor = FactoryBot.create(:user, :tutor)
    @unit.employ_staff(tutor, Role.tutor)
    add_auth_header_for(user: tutor)
    get @path
    assert_equal 403, last_response.status
  end

  def test_same_definition_averages_across_students_and_keeps_other_definitions_separate
    other_student_task = FactoryBot.create(:task, project: FactoryBot.create(:project, unit: @unit),
                                                  task_definition: @task.task_definition)
    other_definition = FactoryBot.create(:task_definition, unit: @unit)
    other_definition_task = @task.project.task_for_task_definition(other_definition)
    empty_definition = FactoryBot.create(:task_definition, unit: @unit)
    assessment(@start, @start + 30.minutes)
    other_student_task.task_submissions.create!(submission_time: @start, assessment_time: @start + 90.minutes,
                                                assessor: @convenor)
    other_definition_task.task_submissions.create!(submission_time: @start, assessment_time: @start + 3.hours,
                                                   assessor: @convenor)
    log_session([[20, @task, 'get-submission-details'], [30, @task, 'assessing'],
                 [86, other_student_task, 'get-submission-details'], [90, other_student_task, 'assessing']])

    rows = report_by_definition
    assert_equal({ 'average_seconds' => 3600, 'assessed_attempt_count' => 2 }, rows.fetch(@task.task_definition_id)['feedback_wait'])
    assert_equal({ 'average_seconds' => 420, 'measured_attempt_count' => 2 }, rows.fetch(@task.task_definition_id)['estimated_marking_time'])
    assert_equal({ 'average_seconds' => 10_800, 'assessed_attempt_count' => 1 }, rows.fetch(other_definition.id)['feedback_wait'])
    assert_equal({ 'average_seconds' => nil, 'measured_attempt_count' => 0 }, rows.fetch(other_definition.id)['estimated_marking_time'])
    assert_equal({ 'average_seconds' => nil, 'assessed_attempt_count' => 0 }, rows.fetch(empty_definition.id)['feedback_wait'])
  end

  def test_switching_to_another_students_task_breaks_the_open_review
    other_task = FactoryBot.create(:task, project: FactoryBot.create(:project, unit: @unit),
                                          task_definition: @task.task_definition)
    assessment(@start, @start + 10.minutes)
    log_session([[2, @task, 'get-submission-details'], [5, other_task, 'get-submission-details'], [10, @task, 'assessing']])
    assert_unmeasured_attempt
  end

  def test_an_open_and_assessment_in_different_sessions_do_not_pair
    assessment(@start, @start + 10.minutes)
    log_session([[2, @task, 'get-submission-details']])
    log_session([[10, @task, 'assessing']])
    assert_unmeasured_attempt
  end

  def test_another_tutors_activity_cannot_measure_the_assessors_time
    tutor = FactoryBot.create(:user, :tutor)
    @unit.employ_staff(tutor, Role.tutor)
    assessment(@start, @start + 10.minutes)
    log_session([[2, @task, 'get-submission-details'], [10, @task, 'assessing']], user: tutor)
    assert_unmeasured_attempt
  end

  def test_status_only_activity_without_a_matching_assessment_does_not_add_marking_time
    assessment(@start, @start + 10.minutes)
    log_session([[2, @task, 'get-submission-details'], [5, @task, 'assessing'], [10, @task, 'assessing']])
    assert_unmeasured_attempt
  end

  def test_same_second_student_submission_counts_as_zero_and_pending_work_is_excluded
    travel_to(@start) { @task.add_status_comment(@task.project.user, TaskStatus.ready_for_feedback) }
    assessment(@start, @start)
    @task.task_submissions.create!(submission_time: @start + 1.day)
    log_session([[0, @task, 'get-submission-details'], [0, @task, 'assessing']])

    row = report_by_definition.fetch(@task.task_definition_id)
    assert_equal({ 'average_seconds' => 0, 'assessed_attempt_count' => 1 }, row['feedback_wait'])
    assert_equal({ 'average_seconds' => 0, 'measured_attempt_count' => 1 }, row['estimated_marking_time'])
  end

  def test_feedback_wait_uses_elapsed_seconds_across_a_daylight_saving_change
    zone = Time.find_zone!('Australia/Sydney')
    assessment(zone.local(2026, 10, 4, 1, 30), zone.local(2026, 10, 4, 3, 30))
    row = report_by_definition.fetch(@task.task_definition_id)
    assert_equal({ 'average_seconds' => 3600, 'assessed_attempt_count' => 1 }, row['feedback_wait'])
  end

  def test_convenor_access_is_scoped_to_the_requested_unit
    other_unit = FactoryBot.create(:unit)
    other_task = FactoryBot.create(:task, project: FactoryBot.create(:project, unit: other_unit))
    other_task.task_submissions.create!(submission_time: @start, assessment_time: @start + 1.hour)
    rows = report_by_definition
    assert_equal @unit.task_definitions.ids.sort, rows.keys.sort
    get "/api/units/#{other_unit.id}/task_turnaround"
    assert_equal 403, last_response.status
  end

  private

  def log_session(events, user: @convenor, start_at: @start)
    session = FactoryBot.create(:marking_session, unit: @unit, user: user,
                                start_time: start_at + events.first.first.minutes,
                                end_time: start_at + events.last.first.minutes)
    events.each do |minutes, task, action|
      session.session_activities.create!(task: task, action: action, created_at: start_at + minutes.minutes)
    end
  end

  def report_by_definition
    get @path
    assert_equal 200, last_response.status
    JSON.parse(last_response.body).fetch('task_definitions').index_by { |row| row.fetch('task_definition_id') }
  end

  def assert_unmeasured_attempt
    row = report_by_definition.fetch(@task.task_definition_id)
    assert_equal({ 'average_seconds' => 600, 'assessed_attempt_count' => 1 }, row['feedback_wait'])
    assert_equal({ 'average_seconds' => nil, 'measured_attempt_count' => 0 }, row['estimated_marking_time'])
  end
end
