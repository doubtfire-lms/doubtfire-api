require 'test_helper'

class ActivityTypesApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_get_all_activity_types
    get '/api/activity_types'
    expected_data = ActivityType.all

    assert_equal expected_data.count, last_response_body.count

    response_keys = %w(name abbreviation)

    last_response_body.each do | data |
      activity_type = ActivityType.find(data['id'])
      assert_json_matches_model(data, activity_type, response_keys)
    end
  end

  def test_post_activity_types
    data_to_post = {
      activity_type: FactoryBot.build(:activity_type),
      auth_token: auth_token
    }
    post_json '/api/activity_types', data_to_post
    assert_equal 201, last_response.status

    response_keys = %w(name abbreviation)
    activity_type = ActivityType.find(last_response_body['id'])
    assert_json_matches_model(last_response_body, activity_type, response_keys)
  end

  def test_put_activity_types
    data_to_put = {
      activity_type: FactoryBot.build(:activity_type),
      auth_token: auth_token
    }

    # Update activity_type with id = 1
    put_json '/api/activity_types/1', data_to_put
    assert_equal 200, last_response.status

    response_keys = %w(name abbreviation)
    first_activity_type = ActivityType.first
    assert_json_matches_model(last_response_body, first_activity_type, response_keys)
  end

  def test_post_activity_types_cannot_auth
    # Number of Activity type before put new activity type
    number_of_activity_type = ActivityType.count

    # A user with student role which does not have premision to put a activity type
    user = FactoryBot.create(:user, :student)

    # Create a dummy activity type
    data_to_post = {
      activity_type: FactoryBot.build(:activity_type),
      auth_token: auth_token
    }

    # Perform POST, but the student user does not have permissions to put it.
    post_json '/api/activity_types', with_auth_token(data_to_post, user)

    # Check if the put does not get through
    assert_equal 403, last_response.status  

    # Check if the number of activity type is the same as initially
    assert_equal ActivityType.count, number_of_activity_type
  end
end
