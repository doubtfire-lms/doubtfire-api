require 'test_helper'

class BreaksApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  #POST TEST
  def test_post_breaks
    teaching_period = FactoryBot.create(:teaching_period)
    start = teaching_period.start_date + 4.weeks
    number_of_break = Break.count

    data_to_post = {
      start_date: start,
      number_of_weeks: rand(1..3)
    }

    add_auth_header_for user: User.first

    # Perform the POST
    post "/api/teaching_periods/#{teaching_period.id}/breaks", data_to_post

    # Check if the POST succeeds
    assert_equal 201, last_response.status

    # Check if the details posted match as expected
    response_keys = %w(start_date number_of_weeks)
    the_break = Break.find(last_response_body['id'])
    assert_json_matches_model(the_break, last_response_body, response_keys)

    # check if the details in the newly created break match as the pre-set data
    assert_equal data_to_post[:start_date].to_date, the_break.start_date.to_date
    assert_equal data_to_post[:number_of_weeks], the_break.number_of_weeks

    # check if one more break is created
    assert_equal Break.count, number_of_break + 1
  end

  # GET TEST
  # Get breaks in a teaching period
  def test_get_breaks
    # Create teaching period
    teaching_period  = FactoryBot.create(:teaching_period)
    teaching_period.add_break teaching_period.start_date + 1.week, 1

    add_auth_header_for(user: User.first)

    # Perform the GET
    get "/api/teaching_periods/#{teaching_period.id}/breaks"
    expected_data = teaching_period.breaks

    # Check if the actual data match as expected
    assert_equal expected_data.count, last_response_body.count
    assert expected_data.count > 0

    response_keys =  %w(id start_date number_of_weeks)
    test_keys =  %w(id number_of_weeks)
    last_response_body.each do | data |
      the_break = Break.find(data['id'])
      assert_json_matches_model(the_break, data, test_keys)
      assert_equal the_break.start_date.strftime('%Y-%m-%d'), data['start_date']
      assert_json_limit_keys_to_exactly(response_keys, data)
    end
  end

  def test_delete_breaks
    # Create teaching period
    teaching_period  = FactoryBot.create(:teaching_period)
    teaching_period.add_break teaching_period.start_date + 1.week, 1
    teaching_period.add_break teaching_period.start_date + 3.week, 1

    add_auth_header_for(user: User.first)
    the_break = Break.last

    count = teaching_period.breaks.count

    # Perform the GET
    delete "/api/teaching_periods/#{teaching_period.id}/breaks/#{the_break.id}"

    teaching_period.reload
    new_count = teaching_period.breaks.count

    assert_equal count - 1, new_count
    assert_equal 200, last_response.status

    # Check if the actual data match as expected
    assert last_response_body
  end
end
