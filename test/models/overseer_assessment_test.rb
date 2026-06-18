require 'test_helper'

class OverseerAssessmentTest < ActiveSupport::TestCase
  def test_selects_latest_failed_unread_assessment_once_grace_period_has_elapsed
    assessment = create_failed_assessment

    pending_ids = OverseerAssessment.awaiting_student_failure_notification.pluck(:id)

    assert_includes pending_ids, assessment.id
  end

  def test_excludes_assessment_when_student_has_read_comment
    assessment = create_failed_assessment
    assessment.latest_assessment_comment.mark_as_read(assessment.project.student)

    pending_ids = OverseerAssessment.awaiting_student_failure_notification.pluck(:id)

    assert_not_includes pending_ids, assessment.id
  end

  def test_excludes_older_failed_assessment_when_a_newer_assessment_exists
    older_failed = create_failed_assessment
    create_assessment(task: older_failed.task, status: :passed, age: 20.minutes)

    pending_ids = OverseerAssessment.awaiting_student_failure_notification.pluck(:id)

    assert_not_includes pending_ids, older_failed.id
  end

  def test_only_selects_latest_failed_assessment_for_a_task
    older_failed = create_failed_assessment
    newer_failed = create_failed_assessment(task: older_failed.task, age: 35.minutes)

    pending_ids = OverseerAssessment.awaiting_student_failure_notification.pluck(:id)

    assert_not_includes pending_ids, older_failed.id
    assert_includes pending_ids, newer_failed.id
  end

  def test_excludes_already_notified_assessment
    assessment = create_failed_assessment
    assessment.update_column(:student_notified_at, Time.current)

    pending_ids = OverseerAssessment.awaiting_student_failure_notification.pluck(:id)

    assert_not_includes pending_ids, assessment.id
  end

  private

  def create_failed_assessment(task: nil, age: 40.minutes)
    create_assessment(task: task, status: :failed, age: age, create_comment: true)
  end

  def create_assessment(status:, age:, task: nil, create_comment: false)
    unit = FactoryBot.create(:unit, task_count: 1) if task.nil?
    task ||= begin
      project = unit.active_projects.first
      project.task_for_task_definition(unit.task_definitions.first)
    end

    submission_timestamp = "#{Time.current.to_i}-#{SecureRandom.hex(2)}"
    assessment = OverseerAssessment.create!(
      task: task,
      submission_history: SubmissionHistory.create!(
        task: task,
        submission_timestamp: submission_timestamp
      ),
      status: status,
      submission_timestamp: submission_timestamp
    )
    assessment.update_columns(created_at: age.ago, updated_at: age.ago)

    if create_comment
      comment = AssessmentComment.create!(
        task: task,
        user: task.project.tutor_for(task.task_definition),
        recipient: task.project.student,
        comment: 'Automated tests failed',
        commentable: assessment
      )
      comment.update_columns(created_at: age.ago)
    end

    assessment
  end
end
