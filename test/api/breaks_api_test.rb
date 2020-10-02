require 'test_helper'

class BreaksApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  
  def app
    Rails.application
  end
  
  #POST TEST
  def test_post_breaks
    teaching_period = FactoryBot.create(:teaching_period)
    start = teaching_period.start_date + 4.weeks
    number_of_break = Break.count

    data_to_post = {
      start_date: start,
      number_of_weeks: rand(1..3),
      auth_token: auth_token 
    }
    
    # Perform the POST
    post "/api/teaching_periods/#{teaching_period.id}/breaks", data_to_post
    
    # Check if the POST succeeds
    assert_equal 201, last_response.status
    
    # Check if the details posted match as expected
    response_keys = %w(start_date number_of_weeks)
    breaks = Break.find(last_response_body['id'])
    assert_json_matches_model(breaks, last_response_body, response_keys)
    
    # check if the details in the newly created break match as the pre-set data
    assert_equal data_to_post[:start_date].to_date, breaks.start_date.to_date
    assert_equal data_to_post[:number_of_weeks], breaks.number_of_weeks
    
    # check if one more break is created
    assert_equal Break.count, number_of_break + 1
  end 
  
  # GET TEST
  # Get breaks in a teaching period
  def test_get_breaks
    # Create teaching period
    teaching_period  = FactoryBot.create(:teaching_period)
  
    # Perform the GET 
    get with_auth_token("/api/teaching_periods/#{teaching_period.id}/breaks")
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
