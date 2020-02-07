require 'test_helper'

class GroupSetsApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::TestFileHelper

  def app
    Rails.application
  end

  def test_post_add_a_group_to_a_group_set_of_a_unit
    # A dummy group
    newGroup = FactoryBot.build(:group)
    newTutorial = FactoryBot.create(:tutorial)
    newGroup.tutorial = newTutorial
    # Create a groupSet
    newGroupSet = FactoryBot.create(:group_set)

    # Obtain the unit from the groupSet
   # newUnit = newGroupSet.unit

    # Create a unit
    newUnit = FactoryBot.create(:unit)
    
    # the dummy group that we want to post/create
    data_to_post = {
      unit_id: 1,
      group_set_id: 1,
      group: {
        name:"abcde",
        tutorial_id:1
      },
      auth_token: auth_token
    }

    # perform the POST
    post_json "/api/units/1/group_sets/1/groups", data_to_post

    # check if the POST get through
    assert_equal 201, last_response.status
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
