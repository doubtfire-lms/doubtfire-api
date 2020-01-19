require 'test_helper'

class ActivityTypesApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_get_an_activity_type_details

    activity_type = FactoryGirl.create(:activity_type)
    get "/api/activity_types/#{activity_type.id}"

    activity_type_id = activity_type.id
 
    activity_type_id = ActivityType.find(activity_type['id'])

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
      activity_type: FactoryGirl.build(:activity_type),
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

  def test_delect_activity_type
    # Create a activity type
    activity_type = FactoryGirl.create(:activity_type)

    # number of activity type before delete
    number_of_ativity_type = ActivityType.count
    
    delete_json with_auth_token "/api/activity_types/#{activity_type.id}"
    assert_equal 200, last_response.status

    # Check delete if success
    assert_equal ActivityType.count, number_of_ativity_type-1
  end

  def test_delect_activity_type_not_auth
    user = FactoryGirl.build(:user, :student)

    activity_type = FactoryGirl.create(:activity_type)

    delete_json with_auth_token("/api/activity_types/#{activity_type.id}", user)

    assert_equal 403, last_response.status
  end
end
