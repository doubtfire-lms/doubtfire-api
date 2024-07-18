require 'test_helper'

class TiiUserAcceptEulaTest < ActiveSupport::TestCase
  include TestHelpers::TiiTestHelper

  def test_can_accept_tii_eula
    setup_tii_eula

    assert TurnItIn.eula_version.present?

    user = FactoryBot.create(:user)

    # Queue job to accept eula
    user.accept_tii_eula

    assert user.tii_eula_date.present?
    assert_equal TurnItIn.eula_version, user.tii_eula_version
    assert_not user.tii_eula_version_confirmed

    assert_equal 1, TiiActionJob.jobs.count

    # Prepare stub for call when eula is accepted
    stub_request(:post, "https://#{ENV['TCA_HOST']}/api/v1/eula/v1beta/accept").
    with(tii_headers).
    to_return(status: 200, body: "", headers: {})

    # Run the job
    TiiActionJob.drain

    # Reload our copy of user
    user.reload

    # Ensure that eula is confirmed
    assert user.tii_eula_version_confirmed
  end

  def test_eula_accept_will_retry
    TiiAction.destroy_all
    setup_tii_eula

    user = FactoryBot.create(:user)

    # Queue job to accept eula
    user.accept_tii_eula

    # Get the action tracking this progress...
    action = TiiActionAcceptEula.last

    assert_not action.complete
    assert action.retry

    assert_not user.tii_eula_version_confirmed

    assert_equal 1, TiiActionJob.jobs.count
    assert_equal user, action.entity

    # Prepare stub for call when eula is accepted and it fails
    accept_stub = stub_request(:post, "https://#{ENV['TCA_HOST']}/api/v1/eula/v1beta/accept").
    with(tii_headers).
    to_return(
      {status: 500, body: "", headers: {} },
      {status: 400, body: "", headers: {} }, # should not reschedule
      {status: 200, body: "", headers: {} },
    )

    # Run the job
    TiiActionJob.drain # First fail
    action.reload

    assert_requested accept_stub, times: 1
    assert_not action.complete
    assert action.retry

    # Reset to retry with check progress sweep
    action.update(last_run: DateTime.now - 31.minutes)

    check_job = TiiCheckProgressJob.new
    check_job.perform # Second fails
    action.reload

    assert_not user.reload.tii_eula_version_confirmed

    assert_requested accept_stub, times: 2
    assert_not action.complete
    assert_not action.retry

    # Reset to retry with check progress sweep
    action.update(last_run: DateTime.now - 31.minutes, retry: true)

    check_job.perform # Third time is a success... via check progress sweep
    action.reload

    assert_requested accept_stub, times: 3
    assert action.complete
    assert_not action.retry

    # Reload our copy of user
    user.reload

    # Ensure that eula is not yet confirmed
    assert user.tii_eula_version_confirmed
  end

  def test_eula_accept_rate_limit
    setup_tii_eula

    # Prepare stub for call when eula is accepted and it fails
    accept_stub = stub_request(:post, "https://#{ENV['TCA_HOST']}/api/v1/eula/v1beta/accept").
      with(tii_headers).
      to_return(
        {status: 429, body: "", headers: {} },
        {status: 200, body: "", headers: {} }, # should not occur
      )

    user = FactoryBot.create(:user)
    # Queue job to accept eula
    user.accept_tii_eula
    action = TiiActionAcceptEula.last

    # Perform manually
    TiiActionJob.jobs.clear

    action.perform

    assert_requested accept_stub, times: 1
    assert TurnItIn.rate_limited?

    # Call does not go to tii as limit applied
    action.perform
    assert_requested accept_stub, times: 1

    # When cleared, the job will run
    TurnItIn.reset_rate_limit

    action.perform
    assert_requested accept_stub, times: 2
  end

  def test_eula_respects_global_errors
    setup_tii_eula

    # Prepare stub for call when eula is accepted and it fails
    accept_stub = stub_request(:post, "https://#{ENV['TCA_HOST']}/api/v1/eula/v1beta/accept").
      with(tii_headers).
      to_return(
        {status: 403, body: "", headers: {} },
        {status: 200, body: "", headers: {} }, # should not occur, until end
      )

    user = FactoryBot.create(:user)
    # Queue job to accept eula
    user.accept_tii_eula

    action = TiiActionAcceptEula.last

    # Make sure we have the right action
    assert_equal user, action.entity

    # Perform manually
    TiiActionJob.jobs.clear
    action.perform

    assert_requested accept_stub, times: 1
    assert_not TurnItIn.functional?

    assert_not action.retry

    action.perform
    # Call does not go to tii as limit applied
    assert_requested accept_stub, times: 1

    # Clear global error
    TurnItIn.global_error = nil
    assert TurnItIn.functional?

    # When cleared, the job will run
    action.perform
    assert_requested accept_stub, times: 2
  end
end
