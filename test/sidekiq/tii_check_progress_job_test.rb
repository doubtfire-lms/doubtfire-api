# frozen_string_literal: true

require 'test_helper'
class TiiCheckProgressJobTest < ActiveSupport::TestCase
  include TestHelpers::TiiTestHelper

  def test_waits_to_process_eula_accept
    # Ensure no users are waiting for eula accept
    User.where(tii_eula_version_confirmed: false).where('tii_eula_date IS NOT NULL').update(tii_eula_version_confirmed: true)

    user = FactoryBot.create(:user, tii_eula_date: DateTime.now)

    job = TiiCheckProgressJob.new
    job.perform

    refute user.reload.tii_eula_version_confirmed

    # Prepare stub for call when eula is accepted
    accept_request = stub_request(:post, "https://#{ENV['TCA_HOST']}/api/v1/eula/v1beta/accept").
    with(tii_headers).
    to_return(status: 200, body: "", headers: {})

    user.update tii_eula_date: DateTime.now - 31.minutes
    job.perform

    assert_requested accept_request, times: 1
    assert user.reload.tii_eula_version_confirmed
  end
end
