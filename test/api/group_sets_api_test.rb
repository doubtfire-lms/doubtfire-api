require 'test_helper'

class GroupSetsApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_post_add_a_new_groupset_to_a_unit_without_authorization
    # A dummy groupSet
    newGroupSet = FactoryBot.build(:group_set)

    # Create a unit
    newUnit = FactoryBot.create(:unit)
    
    # Obtain a student from the unit
    studentUser = newUnit.active_projects.first.student

    # Data that we want to post
    data_to_post = {
      unit_id: newUnit.id,
      group_set: newGroupSet
    }

    # Perform the POST
    post_json with_auth_token("/api/units/#{newUnit.id}/group_sets", studentUser), data_to_post

    # Check error code
    assert_equal 403, last_response.status
  end

  def test_post_add_a_new_groupset_to_a_unit_with_authorization
    # A groupSet we want to save
    newGroupSet = FactoryBot.build(:group_set)

    # Create a unit
    newUnit = FactoryBot.create(:unit)
    
    # Data that we want to post
    data_to_post = {
      unit_id: newUnit.id,
      group_set: newGroupSet,
    }

    # perform the POST
    post_json with_auth_token("/api/units/#{newUnit.id}/group_sets", newUnit.main_convenor_user), data_to_post

    # check if the POST get through
    assert_equal 201, last_response.status
    #check response
    response_keys = %w(name allow_students_to_create_groups allow_students_to_manage_groups keep_groups_in_same_class)
    responseGroupSet = GroupSet.find(last_response_body['id'])
    assert_json_matches_model(last_response_body,responseGroupSet,response_keys)
    assert_equal responseGroupSet.unit.id,newUnit.id
  end

  def test_post_add_a_group_to_a_group_set_of_a_unit_without_authorization
    # Create a groupSet
    newGroupSet = FactoryBot.create(:group_set)

    # Obtain a unit from group_set
    newUnit = newGroupSet.unit

    # A group that we want to save
    newGroup = FactoryBot.build(:group)
    
    # Obtain a tutorial from unit
    newTutorial = newUnit.tutorials.first
    
    # Data to post
    data_to_post = {
      unit_id: newUnit.id,
      group_set_id: newGroupSet.id,
      group: {
        name:newGroup.name,
        tutorial_id:newTutorial.id
      },
      auth_token: auth_token
    }

    # perform the POST
    post_json "/api/units/#{newUnit.id}/group_sets/#{newGroupSet.id}/groups", data_to_post

    # Check error code
    assert_equal 403, last_response.status
  end

  def test_post_add_a_group_to_a_group_set_of_a_unit_with_authorization
    # Create a groupSet
    newGroupSet = FactoryBot.create(:group_set)

    # Obtain a unit from group_set
    newUnit = newGroupSet.unit

    # A group that we want to save
    newGroup = FactoryBot.build(:group)
    
    # Obtain a tutorial from unit
    newTutorial = newUnit.tutorials.first
    
    # Data to post
    data_to_post = {
      unit_id: newUnit.id,
      group_set_id: newGroupSet.id,
      group: {
        name:newGroup.name,
        tutorial_id:newTutorial.id
      }
    }

    # perform the POST
    post_json with_auth_token("/api/units/#{newUnit.id}/group_sets/#{newGroupSet.id}/groups",newUnit.main_convenor_user), data_to_post

    # check if the POST get through
    assert_equal 201, last_response.status
    #check response
    response_keys = %w(name tutorial_id group_set_id number)
    responseGroup = Group.find(last_response_body['id'])
    assert_json_matches_model(last_response_body,responseGroup,response_keys)
    assert_equal newUnit.id, responseGroup.group_set.unit.id
  end

  def test_get_all_groups_in_unit_with_authorization
    # Create a group
    newGroup = FactoryBot.create(:group)
    
    # Obtain the unit from the group
    newUnit = newGroup.group_set.unit
    get with_auth_token "/api/units/#{newUnit.id}/groups",newUnit.main_convenor_user

    #check returning number of groups
    assert_equal newUnit.groups.all.count, last_response_body.count
    
    #Check response
    response_keys = %w(id name)
    last_response_body.each do | data |
      grp = Group.find(data['id'])
      assert_json_matches_model(data, grp, response_keys)
    end
    assert_equal 200, last_response.status
  end

  def test_get_all_groups_in_unit_without_authorization
    # Create a group
    newGroup = FactoryBot.create(:group)
    # Obtain the unit of the group
    newUnit = newGroup.group_set.unit

    # Obtain student object from the unit
    studentUser = newUnit.active_projects.first.student
    get with_auth_token "/api/units/#{newUnit.id}/groups",studentUser
    # Check error code when an unauthorized user tries to get groups in a unit
    assert_equal 403, last_response.status
  end

end
