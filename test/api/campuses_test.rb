require 'test_helper'

class CampusesTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_get_all_campuses
    get '/api/campuses'
    expected_data = Campus.all
    assert_equal expected_data.count, last_response_body.count
    response_keys = %w(name abbreviation)
    last_response_body.each do | data |
      c = Campus.find(data['id'])
      assert_json_matches_model(c, data, response_keys)
    end
  end
  
  def test_get_campuses_by_id
    campus = FactoryBot.create(:campus, mode: 'timetable')
    get "/api/campuses/#{campus.id}"
    response_keys = %w(name abbreviation)
    assert_json_matches_model(campus, last_response_body, response_keys) 
  end

  def test_post_campuses
    data_to_post = {
      campus: FactoryBot.build(:campus, mode: 'timetable'),
      auth_token: auth_token
    }
    post_json '/api/campuses', data_to_post
    assert_equal 201, last_response.status
    response_keys = %w(name abbreviation)
    campus = Campus.find(last_response_body['id'])
    assert_json_matches_model(campus, last_response_body, response_keys)
    assert_equal 0, campus[:mode]
  end

  def test_student_cannot_post_campuses
    user_student = FactoryBot.create(:user, :student)
    data_to_post = { campus: FactoryBot.build(:campus, mode: 'timetable') }
    post_json  with_auth_token("/api/campuses", user_student), data_to_post
    assert_equal 403, last_response.status
  end

  def test_put_campuses
    data_to_put = {
      campus: FactoryBot.build(:campus, mode: 'timetable'),
      auth_token: auth_token
    }
    # Update campus with id = 1
    put_json '/api/campuses/1', data_to_put
    assert_equal 200, last_response.status
    response_keys = %w(name abbreviation)
    first_campus = Campus.first
    assert_json_matches_model(first_campus, last_response_body, response_keys)
    assert_equal 0, first_campus[:mode]
  end

  def test_student_cannot_put_campuses
    user_student = FactoryBot.build(:user, :student)
    data_to_put ={ campus: FactoryBot.create(:campus, mode: 'timetable')}
    put_json with_auth_token("/api/campuses/#{data_to_put[:campus].id}", user_student), data_to_put
    assert_equal 403, last_response.status
  end
    
  def test_delete_campuses        
    campus = FactoryBot.create(:campus, mode: 'timetable')
    initial_num_of_campus = Campus.all.count
    #Perform the delete
    delete_json with_auth_token("/api/campuses/#{campus.id}")
    #check the request went through
    assert_equal 200, last_response.status
    get '/api/campuses' #get number of campuses
    # check if current number of campuses = original number of campuses
    assert_equal initial_num_of_campus - 1, last_response_body.count
    # check campus no longer exists
    refute Campus.exists?(campus.id)
  end

  def test_student_delete_campus
    user_student = FactoryBot.build(:user, :student)
    campus = FactoryBot.create(:campus, mode: 'timetable') 
    # perform the delete
    delete_json with_auth_token("/api/campuses/#{campus.id}", user_student)
    # check that request failed
    assert_equal 403, last_response.status
    # check campus still exists
    assert Campus.exists?(campus.id)
  end
end
