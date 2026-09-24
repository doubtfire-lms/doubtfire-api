# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class SyncLmsIntegrationsJobTest < ActiveSupport::TestCase
  class FakeSource
    attr_reader :groups, :assignments

    def initialize(groups: [], assignments: [], members_error: nil)
      @groups = groups
      @assignments = assignments
      @members_error = members_error
    end

    def course_data_available?
      true
    end

    def members
      raise @members_error if @members_error

      []
    end
  end

  setup do
    config = Doubtfire::Application.config
    @original_config = [config.lti_enabled, config.lti_internal_url, config.lti_internal_key, config.email_errors_to]
    config.lti_enabled = true
    config.lti_internal_url = 'http://lti.test'
    config.lti_internal_key = 'internal-test-key'
  end

  teardown do
    config = Doubtfire::Application.config
    config.lti_enabled, config.lti_internal_url, config.lti_internal_key, config.email_errors_to = @original_config
  end

  def test_scheduled_syncs_are_flagged_as_scheduled
    stub_health
    unit = FactoryBot.create(:unit, with_students: false)
    unit.create_lms_integration!(
      auto_sync_students: true, auto_sync_extensions: true, fetch_extensions: true,
      assignment_id: 5, assignment_name: 'Essay', validated: true
    )

    SyncLmsIntegrationsJob.new.perform

    assert_equal [[unit.id, false, false, true]], ImportLmsStudentsJob.jobs.pluck('args')
    assert_equal [[unit.id, false, true]], ImportLmsExtensionsJob.jobs.pluck('args')
  end

  def test_scheduled_validation_failure_turns_off_auto_sync_and_emails_the_main_convenor
    unit = FactoryBot.create(:unit, with_students: false)
    integration = unit.create_lms_integration!(
      auto_sync_students: true, auto_sync_extensions: true, fetch_extensions: true,
      assignment_id: 5, assignment_name: 'Essay', group_mapping_enabled: true, validated: true
    )
    source = FakeSource.new(groups: [{ id: 7, name: 'Tutorial 01' }], assignments: [{ id: 5, name: 'Essay' }])

    assert_raises(LmsIntegrationValidator::ValidationError) { run_extensions_job(unit, source, scheduled: true) }

    integration.reload
    assert_not integration.auto_sync_students?
    assert_not integration.auto_sync_extensions?
    assert_not integration.validated?
    assert_includes integration.auto_sync_last_error, 'This LMS group has no mapping.'

    assert_equal 1, ActionMailer::Base.deliveries.length
    mail = ActionMailer::Base.deliveries.last
    assert_equal [unit.main_convenor_user.email], mail.to
    assert_includes mail.subject, 'extension sync failed'
    assert_includes mail.text_part.body.to_s, 'Tutorial 01: This LMS group has no mapping.'
    assert_includes mail.text_part.body.to_s, 'Sync students daily'
    assert_includes mail.html_part.body.to_s, '<strong>Tutorial 01:</strong>'
    assert_includes mail.html_part.body.to_s, "/units/#{unit.id}/admin/lms"
  end

  def test_only_the_first_failure_that_needs_the_convenor_sends_an_email
    unit = FactoryBot.create(:unit, with_students: false)
    unit.create_lms_integration!(auto_sync_students: true)
    source = FakeSource.new(members_error: LtiServer::Error.new('The LMS rejected the course membership request (401)', status: 422))

    2.times { assert_raises(LtiServer::Error) { run_students_job(unit, source, scheduled: true) } }

    assert_equal 1, ActionMailer::Base.deliveries.length
    assert_includes ActionMailer::Base.deliveries.last.text_part.body.to_s, 'The error was: The LMS rejected the course membership request (401)'
  end

  def test_an_outage_keeps_auto_sync_on_until_the_grace_period_ends
    unit = FactoryBot.create(:unit, with_students: false)
    integration = unit.create_lms_integration!(auto_sync_students: true)
    source = FakeSource.new(members_error: LtiServer::Error.new('Unable to reach the LTI service', status: 503))

    assert_raises(LtiServer::Error) { run_students_job(unit, source, scheduled: true) }

    integration.reload
    assert integration.auto_sync_students?
    assert_not_nil integration.auto_sync_failing_since
    assert_equal 'Unable to reach the LTI service', integration.auto_sync_last_error
    assert_empty ActionMailer::Base.deliveries

    integration.update!(auto_sync_failing_since: LmsIntegration::AUTO_SYNC_GRACE_DAYS.days.ago)
    assert_raises(LtiServer::Error) { run_students_job(unit, source, scheduled: true) }

    assert_not integration.reload.auto_sync_students?
    assert_equal 1, ActionMailer::Base.deliveries.length
    assert_includes ActionMailer::Base.deliveries.last.text_part.body.to_s, 'has failed every night since'
  end

  def test_a_successful_scheduled_sync_clears_the_failure
    unit = FactoryBot.create(:unit, with_students: false)
    integration = unit.create_lms_integration!(auto_sync_students: true)
    integration.update!(auto_sync_failing_since: 1.day.ago, auto_sync_last_error: 'Unable to reach the LTI service')

    run_students_job(unit, FakeSource.new, scheduled: true)

    integration.reload
    assert_nil integration.auto_sync_failing_since
    assert_nil integration.auto_sync_last_error
  end

  def test_manual_import_failures_are_not_recorded
    unit = FactoryBot.create(:unit, with_students: false)
    integration = unit.create_lms_integration!(auto_sync_students: true)
    source = FakeSource.new(members_error: LtiServer::Error.new('The LMS rejected the course membership request (401)', status: 422))

    assert_raises(LtiServer::Error) { run_students_job(unit, source, scheduled: false) }

    integration.reload
    assert integration.auto_sync_students?
    assert_nil integration.auto_sync_last_error
    assert_empty ActionMailer::Base.deliveries
  end

  def test_an_lti_outage_skips_the_sync_and_emails_ops_once
    Doubtfire::Application.config.email_errors_to = 'ops@example.com'
    stub_request(:get, 'http://lti.test/lti/api/internal/health').to_return(
      status: 503,
      body: { error: 'The LTI service database is unavailable' }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    units = FactoryBot.create_list(:unit, 2, with_students: false)
    integrations = units.map { |unit| unit.create_lms_integration!(auto_sync_students: true) }

    SyncLmsIntegrationsJob.new.perform

    assert_empty ImportLmsStudentsJob.jobs
    assert_equal [['ops@example.com']], ActionMailer::Base.deliveries.map(&:to)
    integrations.each do |integration|
      integration.reload
      assert integration.auto_sync_students?
      assert_equal 'The LTI service database is unavailable', integration.auto_sync_last_error
    end
  end

  def test_a_unit_that_cannot_be_scheduled_does_not_stop_the_others
    stub_health
    broken_unit = FactoryBot.create(:unit, with_students: false)
    broken = broken_unit.create_lms_integration!(auto_sync_students: true, group_mapping_enabled: true)
    healthy_unit = FactoryBot.create(:unit, with_students: false)
    healthy_unit.create_lms_integration!(auto_sync_students: true)

    LmsIntegration.stub(:data_source_for, ->(_unit) { raise 'Unexpected LMS response' }) do
      SyncLmsIntegrationsJob.new.perform
    end

    assert_equal 'Unexpected LMS response', broken.reload.auto_sync_last_error
    assert_equal [[healthy_unit.id, false, false, true]], ImportLmsStudentsJob.jobs.pluck('args')
  end

  private

  def stub_health
    stub_request(:get, 'http://lti.test/lti/api/internal/health').to_return(
      status: 200, body: { ok: true }.to_json, headers: { 'Content-Type' => 'application/json' }
    )
  end

  def run_students_job(unit, source, scheduled:)
    LmsIntegration.stub(:data_source_for, source) { stub_status(ImportLmsStudentsJob.new).perform(unit.id, false, false, scheduled) }
  end

  def run_extensions_job(unit, source, scheduled:)
    LmsIntegration.stub(:data_source_for, source) { stub_status(ImportLmsExtensionsJob.new).perform(unit.id, false, scheduled) }
  end

  def stub_status(job)
    job.define_singleton_method(:total) { |_| nil }
    job.define_singleton_method(:at) { |*_| nil }
    job.define_singleton_method(:store) { |_| nil }
    job
  end
end
