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
    new_group_set = FactoryBot.build(:group_set)

    # Create a unit
    new_unit = FactoryBot.create(:unit)

    # Obtain a student from the unit
    student_user = new_unit.active_projects.first.student

    # Data that we want to post
    data_to_post = {
      unit_id: new_unit.id,
      group_set: new_group_set
    }

    add_auth_header_for user: student_user

    # Perform the POST
    post_json "/api/units/#{new_unit.id}/group_sets", data_to_post

    # Check error code
    assert_equal 403, last_response.status
  end

  def test_post_add_a_new_groupset_to_a_unit_with_authorization
    # A groupSet we want to save
    new_group_set = FactoryBot.build(:group_set)

    # Create a unit
    new_unit = FactoryBot.create(:unit)

    # Data that we want to post
    data_to_post = {
      unit_id: new_unit.id,
      group_set: new_group_set,
    }

    add_auth_header_for user: new_unit.main_convenor_user

    # perform the POST
    post_json "/api/units/#{new_unit.id}/group_sets", data_to_post

    # check if the POST get through
    assert_equal 201, last_response.status
    #check response
    response_keys = %w(name allow_students_to_create_groups allow_students_to_manage_groups keep_groups_in_same_class)
    response_group_set = GroupSet.find(last_response_body['id'])
    assert_json_matches_model(response_group_set, last_response_body, response_keys)
    assert_equal new_unit.id, response_group_set.unit.id
    assert_equal new_group_set.name, response_group_set.name
    assert_equal new_group_set.allow_students_to_create_groups, response_group_set.allow_students_to_create_groups
    assert_equal new_group_set.allow_students_to_manage_groups, response_group_set.allow_students_to_manage_groups
    assert_equal new_group_set.keep_groups_in_same_class, response_group_set.keep_groups_in_same_class
  end

  def test_post_add_a_group_to_a_group_set_of_a_unit_without_authorization
    # Create a groupSet
    new_group_set = FactoryBot.create(:group_set)

    # Obtain a unit from group_set
    new_unit = new_group_set.unit

    # A group that we want to save
    new_group = FactoryBot.build(:group)

    # Obtain a tutorial from unit
    new_tutorial = new_unit.tutorials.first

    # Data to post
    data_to_post = {
      unit_id: new_unit.id,
      group_set_id: new_group_set.id,
      group: {
        name: new_group.name,
        tutorial_id: new_tutorial.id
      }
    }

    add_auth_header_for user: User.find_by(username: 'student_1')

    # perform the POST
    post_json "/api/units/#{new_unit.id}/group_sets/#{new_group_set.id}/groups", data_to_post

    # Check error code
    assert_equal 403, last_response.status
  end

  def test_post_add_a_group_to_a_group_set_of_a_unit_with_authorization
    # Create a groupSet
    new_group_set = FactoryBot.create(:group_set)

    # Obtain a unit from group_set
    new_unit = new_group_set.unit

    # A group that we want to save
    new_group = FactoryBot.build(:group)

    # Obtain a tutorial from unit
    new_tutorial = new_unit.tutorials.first

    # Data to post
    data_to_post = {
      unit_id: new_unit.id,
      group_set_id: new_group_set.id,
      group: {
        name:new_group.name,
        tutorial_id:new_tutorial.id
      }
    }

    add_auth_header_for user: new_unit.main_convenor_user

    # perform the POST
    post_json "/api/units/#{new_unit.id}/group_sets/#{new_group_set.id}/groups", data_to_post

    # check if the POST get through
    assert_equal 201, last_response.status
    #check response
    response_keys = %w(name tutorial_id group_set_id locked)
    responseGroup = Group.find(last_response_body['id'])
    assert_json_matches_model(responseGroup, last_response_body, response_keys)
    assert_equal new_unit.id, responseGroup.group_set.unit.id
    assert_equal new_group.name, responseGroup.name
    assert_equal new_group_set.id,responseGroup.group_set.id
    assert_equal new_tutorial.id,responseGroup.group_set.unit.tutorials.first.id
  end

  def test_get_all_groups_in_unit_without_authorization
    # Create a group
    new_group = FactoryBot.create(:group)
    # Obtain the unit of the group
    new_unit = new_group.group_set.unit

    get "/api/units/#{new_unit.id}/group_sets/#{new_group.group_set_id}/groups"

    # Check error code when an unauthorized user tries to get groups in a unit
    assert_equal 419, last_response.status, last_response_body
  end

  def test_get_all_groups_in_unit_with_authorization
    # Create a group
    new_group = FactoryBot.create(:group)

    # Obtain the unit from the group
    new_unit = new_group.group_set.unit

    add_auth_header_for user: new_unit.main_convenor_user

    get "/api/units/#{new_unit.id}/group_sets/#{new_group.group_set_id}/groups"

    # check returning number of groups
    assert_equal new_group.group_set.groups.count, last_response_body.count

    # Check response
    response_keys = %w(id name)
    last_response_body.each do | data |
      grp = Group.find(data['id'])
      assert_json_matches_model(grp, data, response_keys)
    end
    assert_equal 200, last_response.status
  end

  def test_get_groups_in_a_group_set_without_authorization
    # Create a group
    new_group = FactoryBot.create(:group)

    # Obtain the group_set from group
    new_group_set = new_group.group_set

    # Obtain the unit from the group
    new_unit = new_group.group_set.unit

    add_auth_header_for user: User.find_by(username: 'student_1')

    get "/api/units/#{new_unit.id}/group_sets/#{new_group_set.id}/groups"
    # Check error code
    assert_equal 403, last_response.status
  end

  def test_get_groups_in_a_group_set_with_authorization
    # Create a group
    new_group = FactoryBot.create(:group)

    # Obtain the group_set from group
    new_group_set = new_group.group_set

    # Obtain the unit from the group
    new_unit = new_group.group_set.unit

    add_auth_header_for user: new_unit.main_convenor_user

    get "/api/units/#{new_unit.id}/group_sets/#{new_group_set.id}/groups"

    # Check returning number of groups
    assert_equal new_group_set.groups.all.count,last_response_body.count

    # Check response
    response_keys = %w(id name)
    last_response_body.each do | data |
      grp = Group.find(data['id'])
      assert_json_matches_model(grp, data, response_keys)
    end
    assert_equal 200, last_response.status
  end

  def test_groups_unlocked_upon_creation

    unit = FactoryBot.create :unit
    unit.save!
    group_set = GroupSet.create!({name: 'test_groups_unlocked_upon_creation', unit: unit})
    group_set.save!

    # A group should be unlocked upon creation.
    data = {
      group: {
        name: 'test_groups_unlocked_upon_creation',
        tutorial_id: unit.tutorials.first.id,
        capacity_adjustment: 0,
      },
    }
    add_auth_header_for(user: unit.main_convenor_user)
    post "/api/units/#{unit.id}/group_sets/#{group_set.id}/groups", data
    assert_equal false, last_response_body['locked']

    Group.find(last_response_body['id']).destroy
    group_set.destroy
    unit.destroy
  end

  def test_groups_lockable_only_by_staff
    unit = FactoryBot.create :unit
    unit.save!
    group_set = GroupSet.create!({name: 'test_groups_lockable_only_by_staff', unit: unit, allow_students_to_manage_groups: true })
    group_set.save!
    group = Group.create!({group_set: group_set, name: 'test_groups_lockable_only_by_staff', tutorial: unit.tutorials.first })
    group.save!
    group.add_member(unit.active_projects[0])

    url = "api/units/#{unit.id}/group_sets/#{group_set.id}/groups/#{group.id}"
    lock_data = { group: { locked: true } }
    unlock_data = { group: { locked: false } }

    add_auth_header_for(user: group.projects.first.student)
    # Students shouldn't be able to lock the (currently unlocked because it was just created) group, even though groups
    # within the group set are student-manageable.
    put url, lock_data
    assert_equal 403, last_response.status
    assert_equal false, Group.find(group.id).locked

    add_auth_header_for(user: unit.main_convenor_user)
    # Main convenor should be able to lock the group.
    put url, lock_data
    assert_equal 200, last_response.status
    assert_equal true, Group.find(group.id).locked

    add_auth_header_for(user: group.projects.first.student)
    # Students shouldn't be able to unlock the group either.
    put url, unlock_data
    assert_equal 403, last_response.status
    assert_equal true, Group.find(group.id).locked

    add_auth_header_for(user: unit.main_convenor_user)
    # Main convenor should be able to unlock the locked group.
    put url, unlock_data
    assert_equal 200, last_response.status
    assert_equal false, Group.find(group.id).locked

    group.destroy!
    group_set.destroy!
    unit.destroy!
  end

end
