require 'test_helper'

class TutorialsTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  # --------------------------------------------------------------------------- #
  # --- Endpoint testing for:
  # ------- /api/tutorials
  # ------- POST PUT DELETE

  # --------------------------------------------------------------------------- #

  #####----------POST tests - Create tutorial----------#####

  def assert_tutorial_model_response(response, expected)
    expected = expected.as_json

    # Can't use assert_json_matches_model as keys differ
    assert_equal response[:meeting_day], expected[:day]
    assert_equal response[:meeting_time], expected[:time]
    assert_equal response[:location], expected[:location]
    assert_equal response[:abbrev], expected[:abbrev]
  end

  #1: Testing for successful operation
  # POST /api/tutorials
  def test_tutorials_post
    number_of_tutorials = Tutorial.all.length

    tutorial = {
      unit_id: '1',
      tutor_id: User.first.id,
      campus_id: Campus.first.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial,
      auth_token: auth_token
    }

    # perform the post
    post_json '/api/tutorials', data_to_post

    # Check there is a new tutorial
    assert_equal Tutorial.all.length, number_of_tutorials + 1
    assert_tutorial_model_response last_response_body, tutorial
  end

  #2: Testing for failure due to incorrect auth token
  # POST /api/tutorials
  def test_tutorial_post_incorrect_auth_token

    tutorial = {
      unit_id: '1',
      tutor_id: User.first.id,
      campus_id: Campus.first.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial,
      auth_token: 'Incorrect_Auth_Token'
    }
    # perform the post
    post_json '/api/tutorials', data_to_post

    # Check for authentication failure
    assert_equal 419, last_response.status
  end

  #3: Testing for failure due to empty auth token
  # POST /api/tutorials
  def test_tutorial_post_empty_auth_token

    tutorial = {
      unit_id: '1',
      tutor_id: User.first.id,
      campus_id: Campus.first.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial,
      auth_token: ''
    }
    # perform the post
    post_json '/api/tutorials', data_to_post

    # Check for authentication failure
    assert_equal 419, last_response.status
  end

  #4: Testing for failure due to string as Unit ID
  # POST /api/tutorials
  def test_tutorial_post_string_unit_id

    tutorial = {
      unit_id: 'string',
      tutor_id: User.first.id,
      campus_id: Campus.first.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial,
      auth_token: auth_token
    }

    # perform the post
    post_json '/api/tutorials', data_to_post

    # Check for error in creation
    assert_equal 400, last_response.status
    assert_equal 'tutorial[unit_id] is invalid', last_response_body['error']
  end

  #5: Testing for failure due to string as Tutor ID
  # POST /api/tutorials
  def test_tutorial_post_string_tutor_id

    tutorial = {
      unit_id: '1',
      tutor_id: 'string',
      campus_id: Campus.first.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial,
      auth_token: auth_token
    }

    # perform the post
    post_json '/api/tutorials', data_to_post

    # Check for error in creation
    assert_equal 400, last_response.status
    assert_equal 'tutorial[tutor_id] is invalid', last_response_body['error']
  end

  #6: Testing for failure due POST of already existing task
  # POST /api/tutorials
  def test_tutorials_post_existing_task_error_test

    tutorial = {
      unit_id: '1',
      tutor_id: User.first.id,
      campus_id: Campus.first.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial,
      id: '1',
      auth_token: auth_token
    }
    data_to_post_second = {
      tutorial: tutorial,
      auth_token: auth_token
    }
    #perform the post test
    post_json '/api/tutorials', data_to_post

    assert_equal 201, last_response.status

    #perform the post test for second data set with duplicate values
    post_json '/api/tutorials', data_to_post_second

    #Check for error
    assert_equal 400, last_response.status
    assert last_response_body['error'].include? 'Validation failed'
  end

  #7: Testing for failure due to empty Unit ID
  # POST /api/tutorials
  def test_tutorial_post_empty_unit_id

    tutorial = {
      unit_id: '',
      tutor_id: User.first.id,
      campus_id: Campus.first.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial,
      auth_token: auth_token
    }

    # perform the post
    post_json '/api/tutorials', data_to_post

    # Check for error in creation
    assert_equal 404, last_response.status
    assert_equal 'Unable to find requested Unit', last_response_body['error']
  end

  #8: Testing for failure due to empty Tutor ID
  # POST /api/tutorials
  def test_tutorial_post_empty_tutor_id

    tutorial = {
      unit_id: '1',
      tutor_id: '',
      campus_id: Campus.first.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial,
      auth_token: auth_token
    }

    # perform the post
    post_json '/api/tutorials', data_to_post

    # Check for error in creation
    assert_equal 404, last_response.status
    assert_equal 'Unable to find requested User', last_response_body['error']
  end

  #9: Testing for failure due to empty abbreviation
  # POST /api/tutorials
  def test_tutorial_post_empty_abbreviation

    tutorial = {
      unit_id: '1',
      tutor_id: User.first.id,
      campus_id: Campus.first.id,
      capacity: 10,
      abbreviation: '',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial,
      auth_token: auth_token
    }

    # perform the post
    post_json '/api/tutorials', data_to_post

    # Check for error in creation
    assert_equal 400, last_response.status
    assert last_response_body['error'].include? 'tutorial[abbreviation] is empty'
  end

  #10: Testing for failure due to empty meeting location
  # POST /api/tutorials
  def test_tutorial_post_empty_meeting_location

    tutorial = {
      unit_id: '1',
      tutor_id: User.first.id,
      campus_id: Campus.first.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: '',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial,
      auth_token: auth_token
    }

    # perform the post
    post_json '/api/tutorials', data_to_post

    # Check for error in creation
    assert_equal 400, last_response.status
    assert last_response_body['error'].include? 'meeting_location] is empty'
  end

  #11: Testing for failure due to empty meeting day
  # POST /api/tutorials
  def test_tutorial_post_empty_meeting_day

    tutorial = {
      unit_id: '1',
      tutor_id: User.first.id,
      campus_id: Campus.first.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: '',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial,
      auth_token: auth_token
    }

    # perform the post
    post_json '/api/tutorials', data_to_post

    # Check for error in creation
    assert_equal 400, last_response.status
    assert last_response_body['error'].include? 'meeting_day] is empty'
  end

  #12: Testing for failure due to empty meeting time
  # POST /api/tutorials
  def test_tutorial_post_empty_meeting_time

    tutorial = {
      unit_id: '1',
      tutor_id: User.first.id,
      campus_id: Campus.first.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: ''
    }

    data_to_post = {
      tutorial: tutorial,
      auth_token: auth_token
    }

    # perform the post
    post_json '/api/tutorials', data_to_post

    # Check for error in creation
    assert_equal 400, last_response.status
    assert last_response_body['error'].include? 'meeting_time] is empty'
  end

  #13: Testing for empty meeting time due to string meeting time, other than 3pm
  # POST /api/tutorials
  def test_tutorial_post_string_meeting_time #Other than time string like 3pm
    number_of_tutorials = Tutorial.all.length

    tutorial = {
      unit_id: '1',
      tutor_id: User.first.id,
      campus_id: Campus.first.id,
      capacity: 10,
      abbreviation: 'La011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: 'string'
    }

    outcome_expected = {
    meeting_time: nil
    }

    data_to_post = {
      tutorial: tutorial,
      auth_token: auth_token
    }

    # perform the post
    post_json '/api/tutorials', data_to_post

    # Check for error in creation
    assert_equal number_of_tutorials + 1, Tutorial.all.length
    assert_equal 201, last_response.status
    assert_tutorial_model_response outcome_expected, last_response_body
  end

  #####----------PUT tests - Update a tutorial----------#####

  #14: Testing for successful operation
  # POST /api/tutorials/{id}
  def test_tutorials_put
    number_of_tutorials = Tutorial.all.length

    tutorial_old = Tutorial.first
    tutorial_new = tutorial_old

    tutorial_new[:meeting_time] = '11:30'
    tutorial_new[:meeting_location] = 'AB Building'
    tutorial_new[:meeting_day] = 'Tuesday'
    tutorial_new[:abbreviation] = 'LAB03'

    data_to_put = {
      tutorial: tutorial_new,
      auth_token: auth_token
    }
    # perform the post
    put_json '/api/tutorials/1', data_to_put

    # Check there is a new tutorial
    assert_equal Tutorial.all.length, number_of_tutorials
    assert_equal 200, last_response.status
    assert_tutorial_model_response last_response_body, tutorial_new
  end

  #15: Testing for failure due to empty auth token
  # POST /api/tutorials/{id}
  def test_tutorials_put_empty_auth_token

    tutorial_old = Tutorial.first
    tutorial_new = tutorial_old

    tutorial_new[:meeting_time] = '11:30'
    tutorial_new[:meeting_location] = 'AB Building'
    tutorial_new[:meeting_day] = 'Tuesday'
    tutorial_new[:abbreviation] = 'LAB03'

    data_to_put = {
      tutorial: tutorial_new,
      auth_token: ''
    }
    # perform the post
    put_json '/api/tutorials/1', data_to_put

    # Check there is a new tutorial
    assert_equal 419, last_response.status
  end

  #16: Testing for failure due to incorrect auth token
  # POST /api/tutorials/{id}
  def test_tutorials_put_incorrect_auth_token

    tutorial_old = Tutorial.first
    tutorial_new = tutorial_old

    tutorial_new[:meeting_time] = '11:30'
    tutorial_new[:meeting_location] = 'AB Building'
    tutorial_new[:meeting_day] = 'Tuesday'
    tutorial_new[:abbreviation] = 'LAB03'

    data_to_put = {
      tutorial: tutorial_new,
      auth_token: 'incorrect_auth_token'
    }
    # perform the post
    put_json '/api/tutorials/1', data_to_put

    # Check there is a new tutorial
    assert_equal 419, last_response.status
  end

  #17: Testing for successful operation with empty abbreviation
  # POST /api/tutorials/{id}
  def test_tutorials_put_empty_abbreviation

    tutorial_old = Tutorial.first
    tutorial_new = tutorial_old

    tutorial_new[:meeting_time] = '11:30'
    tutorial_new[:meeting_location] = 'AB Building'
    tutorial_new[:meeting_day] = 'Tuesday'
    tutorial_new[:abbreviation] = ''

    data_to_put = {
      tutorial: tutorial_new,
      auth_token: auth_token
    }
    # perform the post
    put_json '/api/tutorials/1', data_to_put

    # Check there is a new tutorial
    assert_equal 200, last_response.status
  end

  #18: Testing for successful operation with empty meeting location
  # POST /api/tutorials/{id}
  def test_tutorials_put_empty_meeting_location

    tutorial_old = Tutorial.first
    tutorial_new = tutorial_old

    tutorial_new[:meeting_time] = '11:30'
    tutorial_new[:meeting_location] = ''
    tutorial_new[:meeting_day] = 'Tuesday'
    tutorial_new[:abbreviation] = 'LAB03'

    data_to_put = {
      tutorial: tutorial_new,
      auth_token: auth_token
    }
    # perform the post
    put_json '/api/tutorials/1', data_to_put

    # Check there is a new tutorial
    assert_equal 200, last_response.status
  end

  #19: Testing for successful operation with empty meeting location
  # POST /api/tutorials/{id}
  def test_tutorials_put_empty_meeting_day

    tutorial_old = Tutorial.first
    tutorial_new = tutorial_old

    tutorial_new[:meeting_time] = '11:30'
    tutorial_new[:meeting_location] = 'AB Building'
    tutorial_new[:meeting_day] = ''
    tutorial_new[:abbreviation] = 'LAB03'

    data_to_put = {
      tutorial: tutorial_new,
      auth_token: auth_token
    }
    # perform the post
    put_json '/api/tutorials/1', data_to_put

    # Check there is a new tutorial
    assert_equal 200, last_response.status
  end

  #20: Testing for successful operation with empty meeting time
  # POST /api/tutorials/{id}
  def test_tutorials_put_empty_meeting_time

    tutorial_old = Tutorial.first
    tutorial_new = tutorial_old

    tutorial_new[:meeting_time] = ''
    tutorial_new[:meeting_location] = 'AB Building'
    tutorial_new[:meeting_day] = 'Tuesday'
    tutorial_new[:abbreviation] = 'LAB03'

    data_to_put = {
      tutorial: tutorial_new,
      auth_token: auth_token
    }
    # perform the post
    put_json '/api/tutorials/1', data_to_put

    # Check there is a new tutorial
    assert_equal 200, last_response.status
  end

  def delete_json_custom(endpoint, data)
    delete endpoint, data.to_json, 'CONTENT_TYPE' => 'application/json'
  end

  #####----------DELETE tests - Delete a tutorial----------#####

  #21: Testing for successful operation
  # DELETE /api/tutorials/{id}
  def test_tutorials_delete
    number_of_tutorials = Tutorial.all.length
    # Should be random unit where convenor is User.first
    # test_tutorial = Tutorial.where(:convenors == User.first).order('RANDOM()').first
    test_tutorial = Tutorial.all.first
    id_of_tutorial_to_delete = test_tutorial.id

    # Ensure there are no enrolments to enable tutorial to be deleted...
    test_tutorial.tutorial_enrolments.each do |tutorial_enrolment|
      tutorial_enrolment.delete
    end

    data_to_send = {
      auth_token: auth_token
    }
    # perform the post
    delete_json_custom "/api/tutorials/#{id_of_tutorial_to_delete}", data_to_send

    # Check there is one less tutorial
    assert_equal number_of_tutorials - 1, Tutorial.all.length

    # Check that you can't find the deleted id
    refute Tutorial.exists?(id_of_tutorial_to_delete)
    assert_equal 200, last_response.status
  end

  #22: Testing for failure due to string as Tutorial ID
  # DELETE /api/tutorials/{id}
  def test_tutorials_delete_string_tutorial_id
    number_of_tutorials = Tutorial.all.length
    id_of_tutorial_to_delete = 'string'

    data_to_send = {
      auth_token: auth_token
    }
    # perform the post
    delete_json_custom "/api/tutorials/#{id_of_tutorial_to_delete}", data_to_send

    # Check number of tutorials does not change
    assert_equal number_of_tutorials , Tutorial.all.length

    #Check on error of incorrect tutorial ID
    assert_equal 400, last_response.status
    assert_equal 'id is invalid', last_response_body['error']
  end

  #23: Testing for failure due to empty auth token
  # DELETE /api/tutorials/{id}
  def test_tutorials_delete_empty_auth_token
    number_of_tutorials = Tutorial.all.length
    # Should be random unit where convenor is User.first
    # test_tutorial = Tutorial.where(:convenors == User.first).order('RANDOM()').first
    test_tutorial = Tutorial.all.first
    id_of_tutorial_to_delete = test_tutorial.id

    data_to_send = {
      auth_token: ''
    }
    # perform the post
    delete_json_custom "/api/tutorials/#{id_of_tutorial_to_delete}", data_to_send


    # Check authentication error
    assert_equal 419, last_response.status
  end

  #24: Testing for failure due to incorrect auth token
  # DELETE /api/tutorials/{id}
  def test_tutorials_delete_incorrect_auth_token
    number_of_tutorials = Tutorial.all.length
    # Should be random unit where convenor is User.first
    # test_tutorial = Tutorial.where(:convenors == User.first).order('RANDOM()').first
    test_tutorial = Tutorial.all.first
    id_of_tutorial_to_delete = test_tutorial.id

    data_to_send = {
      auth_token: 'incorrect_auth_token'
    }
    # perform the post
    delete_json_custom "/api/tutorials/#{id_of_tutorial_to_delete}", data_to_send


    # Check authentication error
    assert_equal 419, last_response.status
  end

#25: Testing for failure due to unauthorised account
  # Delete a tutorial using unauthorised account
  def test_student_cannot_delete_tutorial
    # A user with student role which does not have permision to delete a tutorial
    user = FactoryBot.build(:user, :student)

    # Tutorial to delete
    tutorial_to_del = FactoryBot.create (:tutorial)
    id_of_tutorial = tutorial_to_del.id

    # Number of tutorials before deletion
    number_of_tutorials = Tutorial.count

    # perform the delete
    delete_json with_auth_token("/api/tutorials/#{id_of_tutorial}", user)

    # check if the delete does not get through
    assert_equal 403, last_response.status

    # check if the number of tutorials is still the same
    assert_equal Tutorial.count, number_of_tutorials

    # Check that you still can find the deleted id
    assert Tutorial.exists?(id_of_tutorial)
  end
end
