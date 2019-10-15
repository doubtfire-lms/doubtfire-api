require 'test_helper'

class CampusesTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def campus
    {
      name: 'Online',
      mode: 'timetable',
      abbreviation: 'O'
    }
  end

  def test_get_all_campuses
    get '/api/campuses'
    expected_data = Campus.all

    assert_equal expected_data.count, last_response_body.count

    response_keys = %w(name abbreviation)

    last_response_body.each do | data |
      c = Campus.find(data['id'])
      assert_json_matches_model(data, c, response_keys)
    end
  end

  def test_post_campuses
    data_to_post = {
      campus: campus,
      auth_token: auth_token
    }
    post_json '/api/campuses', data_to_post
    assert_equal 201, last_response.status

    response_keys = %w(name abbreviation)
    campus = Campus.find(last_response_body['id'])
    assert_json_matches_model(last_response_body, campus, response_keys)
    assert_equal 0, campus[:mode]
  end

  def test_put_campuses
    data_to_put = {
      campus: campus,
      auth_token: auth_token
    }

    # Update campus with id = 1
    put_json '/api/campuses/1', data_to_put
    assert_equal 200, last_response.status

    response_keys = %w(name abbreviation)
    first_campus = Campus.first
    assert_json_matches_model(last_response_body, first_campus, response_keys)
    assert_equal 0, first_campus[:mode]
  end
end
