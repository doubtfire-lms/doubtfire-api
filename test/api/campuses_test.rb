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
      assert_json_matches_model(data, c, response_keys)
    end
  end

  def test_post_campuses
    data_to_post = {
      campus: FactoryGirl.build(:campus, mode: 'timetable'),
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
      campus: FactoryGirl.build(:campus, mode: 'timetable'),
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
    
  def test_delete_campuses    
    initial_num_of_campus = Campus.all.count
    user = User.admins.first

    remove_property(Project)
    remove_property(Tutorial)
    ####################################################

    #delete the stuff
    delete_json with_auth_token("/api/campuses/1",user)
    #check the request went through
    assert_equal 200, last_response.status

    get '/api/campuses' #get number of campuses
    # check if current number of campuses = original number of campuses 
    assert_equal initial_num_of_campus - 1, last_response_body.count
  end

  def test_student_delete_campus
    project = Project.first
    user = project.student
    number_of_campuses = Campus.all.count
    campus_id = Campus.all.first.id

    remove_property(Project)
    remove_property(Tutorial)

    # perform the delete
    delete_json with_auth_token("/api/campuses/#{campus_id}", user)

    assert_equal 403, last_response.status
  end

  #This method required to test campus delete methods
  def remove_property(prop)
      arr = prop.all  
      n = arr.length
    
      for i in 0..n-1 do
        id1 = arr[i].campus.id

        if id1 == 1
          idp = arr[i].id
          prop.find(idp).delete 
        end   
      end
  end
end
