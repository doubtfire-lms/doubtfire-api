require 'test_helper'

class CampusesTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def create_campus
    {
      name: 'Cloud',
      mode: 'online'
    }
  end

  def test_get_all_campuses
    get '/api/campuses'
    expected_data = Campus.all

    assert_equal expected_data.count, last_response_body.count
  end

  def test_post_campuses
    data_to_post = {
      campus: create_campus,
      auth_token: auth_token
    }
    post_json '/api/campuses', data_to_post
    assert_equal 201, last_response.status
  end

  def test_put_campuses
    campus = Campus.first
    data_to_put = {
      campus: campus,
      auth_token: auth_token
    }
    put_json '/api/campuses/1', data_to_put
    assert_equal 200, last_response.status
  end
end