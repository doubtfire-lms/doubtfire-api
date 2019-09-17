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
    assert_equal 200, last_response.status
  end

  def test_get_config_details
    get 'api/settings'
    assert_equal 200, last_response.status
  end
end
