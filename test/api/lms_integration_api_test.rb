require 'test_helper'

class LmsIntegrationApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  setup do
    @original_lti_enabled = Doubtfire::Application.config.lti_enabled
    @original_lti_internal_url = Doubtfire::Application.config.lti_internal_url
    @original_lti_internal_key = Doubtfire::Application.config.lti_internal_key
    Doubtfire::Application.config.lti_enabled = true
    Doubtfire::Application.config.lti_internal_url = 'http://lti.test'
    Doubtfire::Application.config.lti_internal_key = 'internal-test-key'
  end

  teardown do
    Doubtfire::Application.config.lti_enabled = @original_lti_enabled
    Doubtfire::Application.config.lti_internal_url = @original_lti_internal_url
    Doubtfire::Application.config.lti_internal_key = @original_lti_internal_key
  end

  def test_convenor_can_retry_grade_line_item_setup
    unit = FactoryBot.create(:unit, with_students: false)
    add_auth_header_for(user: unit.main_convenor_user)
    stub_link(unit)
    retry_request = stub_request(:post, internal_url(unit, 'grade-line-item'))
                    .with(headers: { 'X-Internal-Key' => 'internal-test-key' })
                    .to_return(
                      status: 200,
                      body: grade_line_item_status(configured: true).to_json,
                      headers: { 'Content-Type' => 'application/json' }
                    )

    post "/api/units/#{unit.id}/lms/grade_line_item"

    assert_equal 201, last_response.status, last_response.inspect
    assert last_response_body['configured']
    assert_requested retry_request
  end

  def test_student_cannot_retry_grade_line_item_setup
    unit = FactoryBot.create(:unit, with_students: false)
    add_auth_header_for(user: FactoryBot.create(:user, :student))

    post "/api/units/#{unit.id}/lms/grade_line_item"

    assert_equal 403, last_response.status, last_response.inspect
  end

  def test_retry_grade_line_item_propagates_lti_error
    unit = FactoryBot.create(:unit, with_students: false)
    add_auth_header_for(user: unit.main_convenor_user)
    stub_link(unit)
    stub_request(:post, internal_url(unit, 'grade-line-item')).to_return(
      status: 422,
      body: { error: 'Enable Assignment and Grade Services, relaunch OnTrack and retry.' }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    post "/api/units/#{unit.id}/lms/grade_line_item"

    assert_equal 422, last_response.status, last_response.inspect
    assert_equal 'Enable Assignment and Grade Services, relaunch OnTrack and retry.',
                 last_response_body['error']
  end

  def test_grade_sync_is_not_queued_without_a_configured_line_item
    unit = FactoryBot.create(:unit, with_students: false)
    add_auth_header_for(user: unit.main_convenor_user)
    stub_link(unit)
    stub_request(:get, internal_url(unit, 'grade-line-item')).to_return(
      status: 200,
      body: grade_line_item_status(configured: false).to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    post "/api/units/#{unit.id}/lms/sync_grades"

    assert_equal 422, last_response.status, last_response.inspect
    assert_equal 'Grade sync is not configured for this LMS course.', last_response_body['error']
    assert_empty SyncLmsGradesJob.jobs
  end

  def test_grade_sync_preview_is_queued_without_a_configured_line_item
    unit = FactoryBot.create(:unit, with_students: false)
    add_auth_header_for(user: unit.main_convenor_user)
    stub_link(unit)

    post "/api/units/#{unit.id}/lms/sync_grades", { preview_only: true }

    assert_equal 201, last_response.status, last_response.inspect
    assert_equal([[unit.id, true]], SyncLmsGradesJob.jobs.map { |job| job['args'] })
  ensure
    SyncLmsGradesJob.clear
  end

  private

  def internal_url(unit, path)
    "http://lti.test/lti/api/internal/units/#{unit.id}/#{path}"
  end

  def stub_link(unit)
    stub_request(:get, internal_url(unit, 'link')).to_return(
      status: 200,
      body: { linked: true, contextId: 'course-1' }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end

  def grade_line_item_status(configured:)
    return { configured: false, visibility: 'unknown' } unless configured

    {
      configured: true,
      visibility: 'unknown',
      lineItem: { id: 'https://moodle.test/lineitem/1', label: 'OnTrack', scoreMaximum: 100 }
    }
  end
end
