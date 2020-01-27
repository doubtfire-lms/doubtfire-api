require 'test_helper'

class BreaksApiTest < ActiveSupport::TestCase
include Rack::Test::Methods
include TestHelpers::AuthHelper
include TestHelpers::JsonHelper

def app
    Rails.application
end

# GET TEST
# Get breaks in a teaching period
def test_unit_main_convenor_get_breaks_in_a_Teaching_Period
    # Create a dummy unit and set teaching period for the unit
    unit = FactoryBot.create(:unit, teaching_period: FactoryBot.create(:teaching_period))
    teaching_period = unit.teaching_period
    
    # Perform the GET with unit main convenor user
    get with_auth_token("/api/teaching_periods/#{teaching_period.id}/breaks", unit.main_convenor_user)
    expected_data = teaching_period.breaks
    
    # Check if the actual data match as expected
    assert_equal expected_data.count, last_response_body.count
    response_keys =  %w(start_date number_of_weeks)
    last_response_body.each do | data |
      breaks = Break.find(data['id'])
      assert_json_matches_model(data, breaks, response_keys)
  end 
end

end