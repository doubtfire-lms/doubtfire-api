# frozen_string_literal: true

require 'test_helper'
class TiiCheckProgressJobTest < ActiveSupport::TestCase
  include TestHelpers::TiiTestHelper

  def test_check_eula_change
    TiiAction.delete_all
    setup_tii_features_enabled
    setup_tii_eula

    # Create a task definition with two attachments
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0, stream_count: 0)

    task_def = FactoryBot.create(:task_definition, unit: unit, upload_requirements: [
      {
        'key' => 'file0',
        'name' => 'My document',
        'type' => 'document',
        'tii_check' => 'true',
        'tii_pct' => '10'
      }
    ])

    # Setup users
    convenor = unit.main_convenor_user
    tutor = FactoryBot.create(:user, :tutor)
    student = FactoryBot.create(:user, :student)

    # Add users to unit
    tutor_unit_role = unit.employ_staff(tutor, Role.tutor)
    project = unit.enrol_student(student, Campus.first)

    # Create tutorial and enrol
    tutorial = FactoryBot.create(:tutorial, unit: unit, campus: Campus.first, unit_role: tutor_unit_role)

    project.enrol_in tutorial

    task = project.task_for_task_definition(task_def)

    # Create a submission
    sub1 = TiiSubmission.create(
      task: task,
      idx: 0,
      filename: 'test.doc',
      status: :created,
      submitted_by_user: student
    )
    sub2 = TiiSubmission.create(
      task: task,
      idx: 0,
      filename: 'test.doc',
      status: :created,
      submitted_by_user: student
    )
    sub3 = TiiSubmission.create(
      task: task,
      idx: 0,
      filename: 'test.doc',
      status: :created,
      submitted_by_user: student
    )

    action = TiiActionUploadSubmission.find_or_create_by(entity: sub1)

    # Test fail as not EULA accepted
    action.perform

    assert_not action.retry
    assert_not action.complete
    assert_equal TiiActionUploadSubmission::NO_USER_ACCEPTED_EULA_ERROR, action.custom_error_message

    # Now have convenor accept EULA
    convenor.tii_eula_date = DateTime.now
    convenor.tii_eula_version = TurnItIn.eula_version
    convenor.save

    # Check the convenor has accepted
    assert convenor.accepted_tii_eula?

    # See if we can retry
    action.attempt_retry_on_no_eula

    assert action.retry
    assert_not action.complete
    assert_equal convenor, sub1.submitted_by

    convenor.tii_eula_version = nil
    convenor.tii_eula_date = nil
    convenor.save
    assert_not convenor.accepted_tii_eula?

    # Reset... to try with tutor
    action = TiiActionUploadSubmission.find_or_create_by(entity: sub2)
    action.perform

    # Tutor accepts eula
    tutor.tii_eula_date = DateTime.now
    tutor.tii_eula_version = TurnItIn.eula_version
    tutor.save

    # Check the tutor has accepted
    assert tutor.accepted_tii_eula?

    # See if we can retry
    action.attempt_retry_on_no_eula

    assert action.retry
    assert_not action.complete
    assert_equal tutor, sub2.submitted_by

    tutor.tii_eula_version = nil
    tutor.tii_eula_date = nil
    tutor.save
    assert_not tutor.accepted_tii_eula?

    # Reset... to try with student
    action = TiiActionUploadSubmission.find_or_create_by(entity: sub3)
    action.perform

    # Student accepts eula
    student.tii_eula_date = DateTime.now
    student.tii_eula_version = TurnItIn.eula_version
    student.save

    # Check the student has accepted
    assert student.accepted_tii_eula?

    # See if we can retry
    action.attempt_retry_on_no_eula

    assert action.retry
    assert_not action.complete
    assert_equal student, sub3.submitted_by
  ensure
    unit.destroy
  end

  def test_that_progress_checks_eula_change
    TiiAction.delete_all

    setup_tii_eula
    setup_tii_features_enabled

    # Create a task definition with two attachments
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0, stream_count: 0)

    task_def = FactoryBot.create(:task_definition, unit: unit, upload_requirements: [
      {
        'key' => 'file0',
        'name' => 'My document',
        'type' => 'document',
        'tii_check' => 'true',
        'tii_pct' => '10'
      }
    ])

    # Setup users
    convenor = unit.main_convenor_user
    tutor = FactoryBot.create(:user, :tutor)
    student = FactoryBot.create(:user, :student)

    # Add users to unit
    tutor_unit_role = unit.employ_staff(tutor, Role.tutor)
    project = unit.enrol_student(student, Campus.first)

    # Create tutorial and enrol
    tutorial = FactoryBot.create(:tutorial, unit: unit, campus: Campus.first, unit_role: tutor_unit_role)

    project.enrol_in tutorial

    task = project.task_for_task_definition(task_def)

    # Create a submission
    sub1 = TiiSubmission.create(
      task: task,
      idx: 0,
      filename: 'test.doc',
      status: :created,
      submitted_by_user: student
    )

    action = TiiActionUploadSubmission.find_or_create_by(entity: sub1)

    # Test fail as not EULA accepted
    action.perform

    assert_not action.retry
    assert_not action.complete
    assert_equal TiiActionUploadSubmission::NO_USER_ACCEPTED_EULA_ERROR, action.custom_error_message

    # Get the job
    job = TiiCheckProgressJob.new

    # Performing the job does not chaange the action - no eula change
    job.perform

    action.reload
    assert_not action.retry
    assert_not action.complete

    # Now have convenor accept EULA
    convenor.tii_eula_date = DateTime.now
    convenor.tii_eula_version = TurnItIn.eula_version
    convenor.save

    # Perform progress check job
    job.perform

    # Will trigger retry of action, but wont perform as it is not old
    action.reload
    assert action.retry
    assert_not action.complete

    unit.destroy
  end

  def test_waits_to_process_action
    setup_tii_eula
    setup_tii_features_enabled

    # Will test with user eula
    user = FactoryBot.create(:user)

    # Prepare stub for call when eula is accepted
    accept_request = stub_request(:post, "https://#{ENV['TCA_HOST']}/api/v1/eula/v1beta/accept").
    with(tii_headers).
    to_return(
      {status: 503, body: "", headers: {}},
      {status: 429, body: "", headers: {}},
      {status: 200, body: "", headers: {}}
    )

    # start an action
    user.accept_tii_eula

    # Check it triggered its processing - but then kill that
    assert_equal 1, TiiActionJob.jobs.count
    TiiActionJob.jobs.clear # Dont run the job... yet

    # Get the action
    action = TiiActionAcceptEula.last
    assert action.retry # still waiting to try
    refute action.last_run.present?

    # Check the user
    assert user.reload.accepted_tii_eula?
    refute user.tii_eula_version_confirmed

    # No call yet...
    assert_requested accept_request, times: 0

    # Get the job
    job = TiiCheckProgressJob.new

    job.perform
    # Still waiting...
    assert_requested accept_request, times: 0

    # Update created at - to test issue with first run
    action.update(created_at: DateTime.now - 31.minutes)

    job.perform # Run it once
    assert_requested accept_request, times: 1

    action.reload
    assert_equal 1, action.retries
    assert action.retry
    refute action.complete
    assert_equal :service_not_available, action.error_code_sym

    # We just tried this...
    assert action.last_run > DateTime.now - 1.minute

    job.perform # Still not time... for attempt 2
    assert_requested accept_request, times: 1

    action.update(last_run: DateTime.now - 31.minutes)
    job.perform # attempt 2 - rate limit

    assert_requested accept_request, times: 2
    assert action.reload.retry
    assert action.last_run > DateTime.now - 1.minute
    assert_equal 2, action.retries
    assert_equal :rate_limited, action.error_code_sym

    job.perform # Still not time... for attempt 3
    assert_requested accept_request, times: 2

    assert action.reload.retry
    assert_not action.complete

    action.update(last_run: DateTime.now - 31.minutes)
    job.perform # attempt 3 - but rate limited

    assert_requested accept_request, times: 2

    # Reset rate limit and try again
    TurnItIn.reset_rate_limit
    action.update(last_run: DateTime.now - 31.minutes)

    job.perform # attempt 3 - success
    assert_requested accept_request, times: 3

    # Check it was all success
    assert action.reload.complete
    assert_not action.retry

    assert user.reload.accepted_tii_eula?
    assert user.tii_eula_version_confirmed
  end
end
