require 'test_helper'

class LtiSecretTest < ActiveSupport::TestCase
  test 'rejects missing, example and short LTI secrets' do
    assert_equal 'is not set', Doubtfire::Application.lti_api_secret_problem(nil)
    assert_equal 'is not set', Doubtfire::Application.lti_api_secret_problem('  ')
    assert_equal 'is still the example value', Doubtfire::Application.lti_api_secret_problem('your-secret-lti-shared-api-secret')
    assert_equal 'must be at least 32 bytes', Doubtfire::Application.lti_api_secret_problem('a' * 31)
  end

  test 'accepts a generated LTI secret' do
    assert_nil Doubtfire::Application.lti_api_secret_problem(SecureRandom.hex(32))
  end
end
