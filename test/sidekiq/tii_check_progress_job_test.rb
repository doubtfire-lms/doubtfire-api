# frozen_string_literal: true

require 'test_helper'
class TiiCheckProgressJobTest < ActiveSupport::TestCase
  include TestHelpers::TiiTestHelper

  def test_waits_to_process_action
    setup_tii_eula

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
    refute action.complete

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
    refute action.retry

    assert user.reload.accepted_tii_eula?
    assert user.tii_eula_version_confirmed
  end
end
