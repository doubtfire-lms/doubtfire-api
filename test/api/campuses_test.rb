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
  
  def test_get_campuses_by_id
    campus_id = Campus.all.first.id
    get "/api/campuses/#{campus_id}"
    expected_data = Campus.all.first
    response_keys = %w(name abbreviation)
    assert_json_matches_model(last_response_body,expected_data,response_keys)
    
  
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
###############################################################################  
  def test_student_post_campuses
    project = Project.first
    user = project.student
    data_to_post = {
      campus: FactoryGirl.build(:campus, mode: 'timetable')
    }

    post_json  with_auth_token("/api/campuses", user), data_to_post
    assert_equal 403, last_response.status
 
  end
###############################################################################
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
  ##############################################################################
  def test_student_put_campuses
    project = Project.first
    user = project.student
    campus_id = Campus.all.first.id
    data_to_put = {
      campus: FactoryGirl.build(:campus, mode: 'timetable')
    }

    put_json  with_auth_token("/api/campuses/#{campus_id}", user), data_to_put
    assert_equal 403, last_response.status
 
  end
    
  def test_delete_campuses    
    initial_num_of_campus = Campus.all.count
    user = User.admins.first
    campus_id = Campus.all.first.id
    #Remove all porjects and tutorials from target campus, as
    #cannot be deleted if has active projects or tutorials

    remove_associated_campus_property(Tutorial,campus_id)
    remove_associated_campus_property(Project,campus_id)


    #Perform the delete
    delete_json with_auth_token("/api/campuses/#{campus_id}",user)
    #check the request went through
    assert_equal 200, last_response.status

    get '/api/campuses' #get number of campuses
    # check if current number of campuses = original number of campuses
    assert_equal initial_num_of_campus - 1, last_response_body.count
  end

  def test_student_delete_campus
    project = Project.first
    user = project.student
    campus_id = Campus.all.first.id

    # perform the delete
    delete_json with_auth_token("/api/campuses/#{campus_id}", user)
    # check that request failed
    assert_equal 403, last_response.status
  end

  #This method removes all properties associated with campuses
  #required to delete the campus

  def remove_associated_campus_property(property,target_campus_id)
      property_array = property.all  
      n_campuses = property_array.length

      for i in 0..n_campuses-1 do
        current_campus_id = property_array[i].campus.id

        if current_campus_id == target_campus_id
          property.find(property_array[i].id).delete
        end  

      end
  end
end
