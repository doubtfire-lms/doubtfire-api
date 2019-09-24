require 'test_helper'

class SettingsTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_get_privacy_policy_details
    get 'api/settings/privacy'

    expected_privacy = Doubtfire::Application.config.institution[:privacy]
    expected_plagiarism = Doubtfire::Application.config.institution[:plagiarism]

    assert_equal 200, last_response.status
    assert_equal expected_privacy, last_response_body['privacy']
    assert_equal expected_plagiarism, last_response_body['plagiarism']
  end

  def test_get_config_details
    get 'api/settings'
    assert_equal 200, last_response.status
  end
end
