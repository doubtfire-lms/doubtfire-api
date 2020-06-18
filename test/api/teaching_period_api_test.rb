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
      assert_json_matches_model(tp, data, response_keys)
    end
  end

  # Get a teaching period's details
  def test_get_a_teaching_periods_details
    #create a dummy variable
    expected_tp = FactoryBot.create(:teaching_period)

    # perform the GET
    get "/api/teaching_periods/#{expected_tp.id}"
    actual_tp = last_response_body

    # Check if the call succeeds
    assert_equal 200, last_response.status

    # Check the returned details match as expected
    assert_equal actual_tp['period'], expected_tp.period
    assert_equal actual_tp['active_until'].to_date, expected_tp.active_until.to_date
    assert_equal actual_tp['start_date'].to_date, expected_tp.start_date.to_date
    assert_equal actual_tp['end_date'].to_date, expected_tp.end_date.to_date
  end

  # PUT tests
  # Update break from teaching period
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

  # Replace a teaching period
  def test_put_teaching_period
    # a dummy teaching period
    tp = FactoryBot.create(:teaching_period)

    # data to replace
    data_to_put = {
      teaching_period: FactoryBot.build(:teaching_period),
      auth_token: auth_token
    }

    # Update teaching period with id = 1
    put_json "/api/teaching_periods/#{tp.id}", data_to_put

    # check if the POST get through
    assert_equal 200, last_response.status

    # check if the details posted match as expected
    response_keys = %w(period year start_date end_date active_until)
    tp_updated = tp.reload
    assert_json_matches_model(tp_updated, last_response_body, response_keys)

    # check if the details in the replaced teaching period match as data set to replace
    assert_equal data_to_put[:teaching_period]['period'], tp_updated.period
    assert_equal data_to_put[:teaching_period]['active_until'].to_date, tp_updated.active_until.to_date
    assert_equal data_to_put[:teaching_period]['start_date'].to_date, tp_updated.start_date.to_date
    assert_equal data_to_put[:teaching_period]['end_date'].to_date, tp_updated.end_date.to_date
  end
  
  # Put teaching period using unauthorised account
  def test_student_cannot_put_teaching_period
    # A user with student role which does not have permission to put a teaching period
    user = FactoryBot.create(:user, :student)

    # Create a new teaching period
    teaching_period = FactoryBot.create(:teaching_period)

    # Number of teaching period before put new teaching period
    number_of_tp = TeachingPeriod.count

    # Create a dummy teaching period 
    data_to_put = {
      teaching_period: FactoryBot.build(:teaching_period),
      auth_token: auth_token
    }

    # Perform PUT, but the student user does not have permissions to put it
    put_json "/api/teaching_periods/#{teaching_period.id}", with_auth_token(data_to_put, user)

    # Check if the put does not get through
    assert_equal 403, last_response.status

    # Check if the number of teaching period is same as initially
    assert_equal TeachingPeriod.count, number_of_tp
  end

  # POST tests
  # Post teaching period
  def test_post_teaching_period
    # the number of teaching period before post
    number_of_tp = TeachingPeriod.count

    # the dummy teaching period that we want to post/create
    data_to_post = {
      teaching_period: FactoryBot.build(:teaching_period),
      auth_token: auth_token
    }

    # perform the POST
    post_json '/api/teaching_periods', data_to_post

    # check if the POST get through
    assert_equal 201, last_response.status

    # check if the details posted match as expected
    response_keys = %w(period year start_date end_date active_until)
    teaching_period = TeachingPeriod.find(last_response_body['id'])
    assert_json_matches_model(teaching_period, last_response_body, response_keys)

    # check if the details in the newly created teaching period match as the pre-set data
    assert_equal data_to_post[:teaching_period]['period'], teaching_period.period
    assert_equal data_to_post[:teaching_period]['active_until'].to_date, teaching_period.active_until.to_date
    assert_equal data_to_post[:teaching_period]['start_date'].to_date, teaching_period.start_date.to_date
    assert_equal data_to_post[:teaching_period]['end_date'].to_date, teaching_period.end_date.to_date

    # check if one more teaching period is created
    assert_equal TeachingPeriod.count, number_of_tp + 1
  end

  # DELETE tests
  # Delete a teaching period
  def test_delete_teaching_period
    # create a dummy teaching period
    teaching_period = FactoryBot.create (:teaching_period)
    id_of_tp = teaching_period.id

    # number of teaching periods before delete
    number_of_tp = TeachingPeriod.count

    # perform the delete
    delete_json with_auth_token"/api/teaching_periods/#{teaching_period.id}"

    # Check if the delete get through
    assert_equal 200, last_response.status

    # Check if the number of teaching period reduces by 1
    assert_equal TeachingPeriod.count, number_of_tp -1

    # Check that you can't find the deleted id
    refute TeachingPeriod.exists?(id_of_tp)
  end

  # Delete a teaching period using unauthorised account
  def test_student_cannot_delete_teaching_period
    # A user with student role which does not have permision to delete a teaching period
    user = FactoryBot.build(:user, :student)

    # Teaching period to delete
    teaching_period = FactoryBot.create (:teaching_period)
    id_of_tp = teaching_period.id

    # Number of teaching periods before deletion
    number_of_tp = TeachingPeriod.count

    # perform the delete
    delete_json with_auth_token("/api/teaching_periods/#{id_of_tp}", user)

    # check if the delete does not get through
    assert_equal 403, last_response.status

    # check if the number of teaching period is still the same
    assert_equal TeachingPeriod.count, number_of_tp

    # Check that you still can find the deleted id
    assert TeachingPeriod.exists?(id_of_tp)
  end
end
