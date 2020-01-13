require 'test_helper'

class BreaksApiTest < ActiveSupport::TestCase
include Rack::Test::Methods
include TestHelpers::AuthHelper
include TestHelpers::JsonHelper

def app
    Rails.application
end

# GET TEST 
# Get All Breaks
def test_get_all_breaks
    user = User.admins.first
    get with_auth_token('/api/breaks',user)
    expected_data = Break.all
    assert_equal expected_data.count, last_response_body.count
    response_keys = %w(start_date number_of_weeks)
    last_response_body.each do | data |
        breaks = Break.find(data['id'])
        
        assert_json_matches_model(data, breaks, response_keys)
    end 
end


end
