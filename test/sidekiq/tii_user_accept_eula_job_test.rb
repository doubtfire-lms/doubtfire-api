require 'test_helper'

class TiiUserAcceptEulaJobTest < ActiveSupport::TestCase
  include TestHelpers::TiiTestHelper

  def test_can_accept_tii_eula
    setup_tii_eula

    user = FactoryBot.create(:user)

    # Queue job to accept eula
    user.accept_tii_eula

    assert user.tii_eula_date.present?
    assert TurnItIn.eula_version.present?
    assert_equal TurnItIn.eula_version, user.tii_eula_version
    refute user.tii_eula_version_confirmed
    refute user.last_eula_retry.present?
    assert_equal 1, TiiUserAcceptEulaJob.jobs.count

    # Prepare stub for call when eula is accepted
    stub_request(:post, "https://#{ENV['TCA_HOST']}/api/v1/eula/v1beta/accept").
    with(tii_headers).
    to_return(status: 200, body: "", headers: {})

    # Run the job
    TiiUserAcceptEulaJob.drain

    # Reload our copy of user
    user.reload

    # Ensure that eula is confirmed
    assert user.tii_eula_version_confirmed
  end

  def test_eula_accept_will_retry
    setup_tii_eula

    user = FactoryBot.create(:user)

    # Queue job to accept eula
    user.accept_tii_eula

    refute user.last_eula_retry.present?

    assert_equal 1, TiiUserAcceptEulaJob.jobs.count

    # Prepare stub for call when eula is accepted and it fails
    accept_stub = stub_request(:post, "https://#{ENV['TCA_HOST']}/api/v1/eula/v1beta/accept").
    with(tii_headers).
    to_return(
      {status: 500, body: "", headers: {} },
      {status: 400, body: "", headers: {} }, # should not reschedule
      {status: 200, body: "", headers: {} }, # should not occur
    )

    # Run the job
    TiiUserAcceptEulaJob.drain

    # Reload our copy of user
    user.reload

    assert_requested accept_stub, times: 2

    # Ensure that eula is confirmed
    refute user.tii_eula_version_confirmed
    assert user.last_eula_retry.present?
    refute user.tii_eula_retry
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

    # Perform manually
    TiiUserAcceptEulaJob.jobs.clear
    job = TiiUserAcceptEulaJob.new
    job.perform(user.id)

    assert_requested accept_stub, times: 1
    assert TurnItIn.rate_limited?

    job.perform(user.id)
    # Call does not go to tii as limit applied
    assert_requested accept_stub, times: 1

    # When cleared, the job will run
    TurnItIn.reset_rate_limit
    job.perform(user.id)
    assert_requested accept_stub, times: 2
  end

  def test_eula_respects_global_errors
    setup_tii_eula

    # Prepare stub for call when eula is accepted and it fails
    accept_stub = stub_request(:post, "https://#{ENV['TCA_HOST']}/api/v1/eula/v1beta/accept").
      with(tii_headers).
      to_return(
        {status: 403, body: "", headers: {} },
        {status: 200, body: "", headers: {} }, # should not occur
      )

    user = FactoryBot.create(:user)
    # Queue job to accept eula
    user.accept_tii_eula

    # Perform manually
    TiiUserAcceptEulaJob.jobs.clear
    job = TiiUserAcceptEulaJob.new
    job.perform(user.id)

    assert_requested accept_stub, times: 1
    refute TurnItIn.functional?

    job.perform(user.id)
    # Call does not go to tii as limit applied
    assert_requested accept_stub, times: 1

    # Clear global error
    TurnItIn.global_error = nil
    assert TurnItIn.functional?

    # When cleared, the job will run
    job.perform(user.id)
    assert_requested accept_stub, times: 2
  end
end
