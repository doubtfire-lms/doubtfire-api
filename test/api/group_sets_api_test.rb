require 'test_helper'
require 'user'

class GroupSetsApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::TestFileHelper

  def app
    Rails.application
  end

  def test_get_all_groups_in_unit_with_authorization
    # Create a group
    newGroup = FactoryBot.create(:group)
    # Obtain the unit of the group
    newUnit = newGroup.group_set.unit
    get with_auth_token "/api/units/#{newUnit.id}/groups",newUnit.main_convenor_user

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
