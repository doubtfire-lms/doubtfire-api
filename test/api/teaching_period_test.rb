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

  def test_get_teaching_periods_details
    expected_tp = TeachingPeriod.second

    # perform the GET 
    get with_auth_token "/api/teaching_periods/#{expected_tp.id}"
    actual_tp = last_response_body
    assert_equal 200, last_response.status
    
    # Check the returned details match as expected 
    assert_equal actual_tp['period'], expected_tp.period
    assert_equal actual_tp['year'], expected_tp.year
    assert_equal actual_tp['start_date'].to_date, expected_tp.start_date.to_date
    assert_equal actual_tp['end_date'].to_date, expected_tp.end_date.to_date
    assert_equal actual_tp['active_until'].to_date, expected_tp.active_until.to_date
   # assert_equal TeachingPeriodSerializer.new(teaching_period).to_json, last_response.body
  end

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

end
