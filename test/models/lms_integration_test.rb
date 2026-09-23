# frozen_string_literal: true

require 'test_helper'

class LmsIntegrationTest < ActiveSupport::TestCase
  def test_lms_and_course_problems_need_the_convenor
    assert LmsIntegration.convenor_error?(LmsIntegrationValidator::ValidationError.new([{ message: 'Select an LMS assignment.' }]))
    assert LmsIntegration.convenor_error?(LtiCourseDataSource::Error.new('This unit is not linked to an LMS course.'))
    [404, 409, 422].each do |status|
      assert LmsIntegration.convenor_error?(LtiServer::Error.new('LMS problem', status: status)), status
    end
  end

  def test_outages_and_unexpected_errors_do_not_need_the_convenor
    [400, 401, 429, 502, 503].each do |status|
      assert_not LmsIntegration.convenor_error?(LtiServer::Error.new('LTI problem', status: status)), status
    end
    assert_not LmsIntegration.convenor_error?(course_data_error_caused_by(LtiServer::Error.new('Unable to reach the LTI service', status: 503)))
    assert_not LmsIntegration.convenor_error?(RuntimeError.new('Unexpected LMS response'))
  end

  def test_turning_auto_sync_back_on_clears_the_last_failure
    unit = FactoryBot.create(:unit, with_students: false)
    integration = unit.create_lms_integration!
    integration.update!(auto_sync_failing_since: 4.days.ago, auto_sync_last_error: 'Unable to reach the LTI service')

    integration.update!(auto_sync_extensions: true)

    assert_nil integration.auto_sync_failing_since
    assert_nil integration.auto_sync_last_error
  end

  private

  def course_data_error_caused_by(error)
    raise error
  rescue LtiServer::Error => e
    begin
      raise LtiCourseDataSource::Error, e.message
    rescue LtiCourseDataSource::Error => wrapped
      wrapped
    end
  end
end
