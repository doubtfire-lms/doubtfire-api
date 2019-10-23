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
    unit_activity_set = UnitActivitySet.first
    number_of_tutorials = Tutorial.all.length

    tutorial = {
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
    post_json "/api/unit_activity_sets/#{unit_activity_set.id}/tutorials", data_to_post

    # Check there is a new tutorial
    assert_equal Tutorial.all.length, number_of_tutorials + 1
    assert_tutorial_model_response last_response_body, tutorial
  end

  def test_tutorials_put
    unit_activity_set = UnitActivitySet.first
    number_of_tutorials = unit_activity_set.tutorials.all.length

    tutorial_old = unit_activity_set.tutorials.first
    tutorial_new = tutorial_old

    tutorial_new[:meeting_time] = '11:30'
    tutorial_new[:meeting_location] = 'AB Building'
    tutorial_new[:meeting_day] = 'Tuesday'
    tutorial_new[:abbreviation] = 'LAB03'

    # perform the post
    put_json "/api/unit_activity_sets/#{unit_activity_set.id}/tutorials/#{tutorial_old.id}", tutorial_new

    # Check there is a new tutorial
    assert_equal unit_activity_set.tutorials.all.length, number_of_tutorials

    assert_tutorial_model_response last_response_body, tutorial_new
  end

  def test_tutorials_delete
    unit_activity_set = UnitActivitySet.first
    number_of_tutorials = unit_activity_set.tutorials.all.length
    # Should be random unit where convenor is User.first
    # test_tutorial = Tutorial.where(:convenors == User.first).order('RANDOM()').first
    test_tutorial = unit_activity_set.tutorials.all.first
    id_of_tutorial_to_delete = test_tutorial.id

    # perform the post
    delete_json with_auth_token "/api/unit_activity_sets/#{unit_activity_set.id}/tutorials/#{id_of_tutorial_to_delete}"

    # Check there is one less tutorial
    assert_equal number_of_tutorials - 1, unit_activity_set.tutorials.all.length

    # Check that you can't find the deleted id
    refute Tutorial.exists?(id_of_tutorial_to_delete)
    assert_equal last_response.status, 200
  end
end
