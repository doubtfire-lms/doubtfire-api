require 'test_helper'

class TeachingPeriodTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_get_teaching_periods
    # The GET we are testing
    get '/api/teaching_periods'
    expected_data = TeachingPeriod.all

    puts last_response_body

    assert_equal expected_data.count, last_response_body.count
  end

end
