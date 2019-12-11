require 'test_helper'

class TeachingPeriodTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  # GET tests
  # Get teaching period
  def test_get_teaching_periods
    # The GET we are testing
    get '/api/teaching_periods'
    expected_data = TeachingPeriod.all

    assert_equal expected_data.count, last_response_body.count

    # What are the keys we expect in the data that match the model - so we can check these
    response_keys = %w(start_date year period end_date active_until)

    # Loop through all of the responses
    last_response_body.each do | data |
      # Find the matching teaching period, by id from response
      tp = TeachingPeriod.find(data['id'])
      # Match json with object
      assert_json_matches_model(data, tp, response_keys)
    end
  end

  # Get a teaching period's details
  def test_get_teaching_periods_details
    expected_tp = TeachingPeriod.second

    # perform the GET 
    get "/api/teaching_periods/#{expected_tp.id}"
    returned_tp = last_response_body

    # Check if the call succeeds
    assert_equal 200, last_response.status
    
    # Check the returned details match as expected
    response_keys = %w(period year start_date end_date active_until)
    assert_json_matches_model(returned_tp, expected_tp, response_keys)
  end

  #PUT tests
  def test_update_break_from_teaching_period
    tp = TeachingPeriod.first
    to_update = tp.breaks.first

    # The api call we are testing
    put_json with_auth_token("/api/teaching_periods/#{tp.id}/breaks/#{to_update.id}"), { number_of_weeks: 5 }

    to_update.reload
    assert_equal 5, to_update.number_of_weeks
  end

  def test_update_break_must_be_from_teaching_period
    tp = TeachingPeriod.first
    to_update = TeachingPeriod.last.breaks.first
    num_weeks = to_update.number_of_weeks
    # The api call we are testing
    put_json with_auth_token("/api/teaching_periods/#{tp.id}/breaks/#{to_update.id}"), { number_of_weeks: num_weeks + 1 }

    assert_equal 404, last_response.status

    to_update.reload
    assert_equal num_weeks, to_update.number_of_weeks
  end

  def test_put_activity_types
    data_to_put = {
      activity_type: FactoryGirl.build(:activity_type),
      auth_token: auth_token
    }

    # Update activity_type with id = 1
    put_json '/api/activity_types/1', data_to_put
    assert_equal 200, last_response.status

    response_keys = %w(name abbreviation)
    first_activity_type = ActivityType.first
    assert_json_matches_model(last_response_body, first_activity_type, response_keys)
  end

  # POST tests
  def test_post_teaching_period
    # the number of teaching period
    number_of_tp = TeachingPeriod.count

    # the dummy teaching period that we want to post/create
    data_to_post = {
      teaching_period: FactoryGirl.build(:teaching_period),
      auth_token: auth_token
    }
    
    # perform the POST
    post_json '/api/teaching_periods', data_to_post
    
    # check if the POST get through
    assert_equal 201, last_response.status

    # check if the details posted match as expected
    response_keys = %w(period year start_date end_date active_until)
    teaching_period = TeachingPeriod.find(last_response_body['id'])
    assert_json_matches_model(last_response_body, teaching_period, response_keys)

    # check if one more teaching period is created
    assert_equal TeachingPeriod.count, number_of_tp + 1
  end
end
