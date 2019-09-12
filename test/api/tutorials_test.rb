require 'test_helper'

class TutorialsTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def assert_tutorial_model_response(response, expected)
    expected = expected.as_json

    # Can't use assert_json_matches_model as keys differ
    assert_equal response[:meeting_day], expected[:day]
    assert_equal response[:meeting_time], expected[:time]
    assert_equal response[:location], expected[:location]
    assert_equal response[:abbrev], expected[:abbrev]
  end

  # POST /api/units{id}/tutorials.json
  def test_tutorials_post
    number_of_tutorials = Tutorial.all.length

    tutorial = {
      unit_id: '1',
      tutor_id: User.first.id,
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

    # perform the post
    post_json '/api/tutorials', data_to_post

    # Check there is a new tutorial
    assert_equal Tutorial.all.length, number_of_tutorials + 1
    assert_tutorial_model_response last_response_body, tutorial
  end

  # POST /api/units{id}/tutorials.json
  def test_tutorials_unit_post
    number_of_tutorials = Tutorial.all.length

    tutorial = {
      day: 'Monday',
      time: '12:30',
      location: 'Room B',
      tutor_username: 'acain',
      abbrev: 'LA01'
    }

    data_to_post = {
      tutorial: tutorial,
      id: '1',
      auth_token: auth_token
    }

    # perform the post
    post_json '/api/units/1/tutorials', data_to_post

    # Check there is a new tutorial
    assert_equal Tutorial.all.length, number_of_tutorials + 1
    assert_tutorial_model_response last_response_body, tutorial
  end

  def test_tutorials_put
        tutorial={}
      tutorial[:abbreviation] = 'LAB03'
      tutorial[:meeting_location] = 'AB Building'
      tutorial[:meeting_day] = 'Tuesday'
      tutorial[:meeting_time] = '11:30'

      data_to_put = {
        tutorial:tutorial,
        auth_token: auth_token
  }
      put_json '/api/tutorials/1', data_to_put
      assert_equal 200, last_response.status



  end

  #Test PUT for updating tutorial details with empty abbreviation
  def test_put_update_tutorial_empty_name
    tutorial = Tutorial.first
    tutorial[:abbreviation] = ''

    data_to_put = {
        tutorial: tutorial,
        auth_token: auth_token
    }

    put_json '/api/tutorials/1', data_to_put
    assert_equal 200, last_response.status
  end

  #Test PUT for updating tutorial details with invalid abbreviation
  def test_put_update_tutorial_invalid_abbreviation
  data_to_put = {
      tutorial: { abbreviation: 'test'},
      auth_token: auth_token
  }

  put_json '/api/tutorials/12', data_to_put
  assert_equal 403, last_response.status
  end


  def test_tutorials_delete
    number_of_tutorials = Tutorial.all.length
    # Should be random unit where convenor is User.first
    # test_tutorial = Tutorial.where(:convenors == User.first).order('RANDOM()').first
    test_tutorial = Tutorial.all.first
    id_of_tutorial_to_delete = test_tutorial.id

    # perform the post
    delete_json with_auth_token "/api/tutorials/#{id_of_tutorial_to_delete}"

    # Check there is one less tutorial
    assert_equal number_of_tutorials - 1, Tutorial.all.length

    # Check that you can't find the deleted id
    refute Tutorial.exists?(id_of_tutorial_to_delete)
    assert_equal last_response.status, 200
  end
end
