require 'test_helper'

class UnitRequestsTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end
  def assert_unit_request_model_response(response, expected)
    expected = expected.as_json

    # Can't use assert_json_matches_model as keys differ
    assert_equal response[:unit_id], expected[:unit_id]
    assert_equal response[:user_id], expected[:user_id]
  end

def create_unit_request
    {
      unit_id: '2',
      user_id: '4'    
    }
  end

  def test_unit_request_post(token='abcdef')
    number_of_unit_requests = UnitRequest.all.length 
    data_to_post = {
        unit_id: '1',
        request_at: '2019-5-5',
        auth_token: token
        }

    post_json '/api/unitrequests', data_to_post
    # Successful assertion of same length again means no record was created
    assert_equal number_of_unit_requests+1, UnitRequest.all.length
  end
     
end
