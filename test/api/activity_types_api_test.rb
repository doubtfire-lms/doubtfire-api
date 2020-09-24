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
      expected_data = ActivityType.find(data['id'])
      assert_json_matches_model(expected_data, data, response_keys)
    end
  end

  # POST tests
  # 1: Admin can create a new activity type
  def test_admin_can_post_activity_type
    # Admin user
    admin = FactoryBot.create(:user, :admin)
    
    # the number of teaching period before post
    no_activity_type = ActivityType.count

    # the data that we want to post/create
    data_to_post = {
      activity_type: FactoryBot.build(:activity_type),
      auth_token: auth_token
    }
    
    # perform the POST
    post_json '/api/activity_types', with_auth_token(data_to_post, admin)
    
    # check if the request get through 
    assert_equal 201, last_response.status

    # check if the details posted match as expected
    response_keys = %w(name abbreviation)
    activity_type = ActivityType.find(last_response_body['id'])
    assert_json_matches_model(activity_type, last_response_body, response_keys)

    # check if the details in the newly created match as pre-set data
    assert_equal data_to_post[:activity_type]['name'], activity_type.name
    assert_equal data_to_post[:activity_type]['abbreviation'], activity_type.abbreviation

    # check if one more activity type is created
    assert_equal no_activity_type +1, ActivityType.count
  end

  # 2: Convenor cannot create a new activity type
  def test_convenor_cannot_post_activity_type
    # Convenor user
    convenor = FactoryBot.create(:user, :convenor)
    
    # the number of teaching period before post
    no_activity_type = ActivityType.count

    # the data that we want to post/create
    data_to_post = {
      activity_type: FactoryBot.build(:activity_type),
      auth_token: auth_token
    }
    
    # perform the POST
    post_json '/api/activity_types', with_auth_token(data_to_post, convenor)
    
    # check if the request get through 
    assert_equal 403, last_response.status

    # check if no more activity type is created
    assert_equal no_activity_type, ActivityType.count
  end

  # 3: Tutor cannot create a new activity type
  def test_tutor_cannot_post_activity_type
    # Tutor user
    tutor = FactoryBot.create(:user, :tutor)
    
    # the number of teaching period before post
    no_activity_type = ActivityType.count

    # the data that we want to post/create
    data_to_post = {
      activity_type: FactoryBot.build(:activity_type),
      auth_token: auth_token
    }
    
    # perform the POST
    post_json '/api/activity_types', with_auth_token(data_to_post, tutor)
    
    # check if the request get through 
    assert_equal 403, last_response.status

    # check if no more activity type is created
    assert_equal no_activity_type, ActivityType.count
  end

  # PUT tests
  # 1: Admin can replace an activity type
  def test_admin_can_put_activity_types
    # Admin user
    admin = FactoryBot.create(:user, :admin)

    # The activity type to be replaced
    activity_type = FactoryBot.create(:activity_type)
    
    # Data to replace 
    data_to_put = {
      activity_type: FactoryBot.build(:activity_type),
      auth_token: auth_token
    }

    # Update activity_type with data_to_put
    put_json "/api/activity_types/#{activity_type.id}", with_auth_token(data_to_put, admin)
    
    #check if the request get through
    assert_equal 200, last_response.status

    # check if the details posted match as expected
    response_keys = %w(name abbreviation)
    activity_type_updated = activity_type.reload
    assert_json_matches_model(activity_type_updated, last_response_body, response_keys)

    # check if the details in the replaced teaching period match as data set to replace 
    assert_equal data_to_put[:activity_type]['name'], activity_type_updated.name
    assert_equal data_to_put[:activity_type]['abbreviation'], activity_type_updated.abbreviation
  end

  # 2: Convenor cannot replace an activity type
  def test_convenor_cannot_put_activity_types
    # Convenor user
    convenor = FactoryBot.create(:user, :convenor)

    # The activity type to be replaced
    activity_type = FactoryBot.create(:activity_type)
    
    # Data to replace 
    data_to_put = {
      activity_type: FactoryBot.build(:activity_type),
      auth_token: auth_token
    }

    # Update activity_type with data_to_put
    put_json "/api/activity_types/#{activity_type.id}", with_auth_token(data_to_put, convenor)
    
    #check if the request get through
    assert_equal 403, last_response.status
  end

  # 3: Tutor cannot replace an activity type
  def test_tutor_cannot_put_activity_types
    # Tutor user
    tutor = FactoryBot.create(:user, :tutor)

    # The activity type to be replaced
    activity_type = FactoryBot.create(:activity_type)
    
    # Data to replace 
    data_to_put = {
      activity_type: FactoryBot.build(:activity_type),
      auth_token: auth_token
    }

    # Update activity_type with data_to_put
    put_json "/api/activity_types/#{activity_type.id}", with_auth_token(data_to_put, tutor)
    
    #check if the request get through
    assert_equal 403, last_response.status
  end

  def test_student_cannot_post_activity_type
    # Number of Activity type before post new activity type
    number_of_activity_type = ActivityType.count

    # A user with student role which does not have premision to post a activity type
    user = FactoryBot.create(:user, :student)

    # Create a dummy activity type
    data_to_post = {
      activity_type: FactoryBot.build(:activity_type),
      auth_token: auth_token
    }

    # Perform POST, but the student user does not have permissions to post it.
    post_json '/api/activity_types', with_auth_token(data_to_post, user)

    # Check if the post does not get through
    assert_equal 403, last_response.status  

    # Check if the number of activity type is the same as initially
    assert_equal ActivityType.count, number_of_activity_type
  end  

  def test_student_cannot_put_activity_type
    # A user with student role which does not have premision to put a activity type
    user = FactoryBot.create(:user, :student)

    #Create a new activity type
    activity_type = FactoryBot.create(:activity_type)

    # Number of Activity type before put new activity type
    number_of_activity_type = ActivityType.count    

    # Create a dummy activity type
    data_to_put = {
      activity_type: FactoryBot.build(:activity_type), 
      auth_token: auth_token
    }

    # Perform PUT, but the student user does not have permissions to put it.
    put_json "/api/activity_types/#{activity_type.id}", with_auth_token(data_to_put, user)
    
    # Check if the put does not get through
    assert_equal 403, last_response.status  

    # Check if the number of activity type is the same as initially
    assert_equal ActivityType.count, number_of_activity_type
  end

  def test_delete_activity_type
    # Create a activity type
    activity_type = FactoryBot.create(:activity_type)
          
    #number of activity type before delete
    number_of_ativity_type = ActivityType.count
    
    # perform the delete
    delete_json with_auth_token "/api/activity_types/#{activity_type.id}"
    
    # Check if the delete get through
    assert_equal 200, last_response.status

    # Check delete if success
    assert_equal ActivityType.count, number_of_ativity_type-1

    # Check that you can't find the deleted id
    refute ActivityType.exists?(activity_type.id)
  end

  def test_student_cannot_delete_activity_type
    # A user with student role which does not have permision to delete a activity type
    user = FactoryBot.build(:user, :student)
    
    # create a activity type to delete
    activity_type = FactoryBot.create (:activity_type)
    
    # number of activity type before delete
    number_of_ativity_type = ActivityType.count

    # perform the delete
    delete_json with_auth_token("/api/activity_types/#{activity_type.id}", user)
   
    # check if the delete does not get through
    assert_equal 403, last_response.status

    # check if the number of ativity_type is still the same
    assert_equal ActivityType.count, number_of_ativity_type

    # # Check that you still can find the deleted id
   assert ActivityType.exists?(activity_type.id)

  end
end
