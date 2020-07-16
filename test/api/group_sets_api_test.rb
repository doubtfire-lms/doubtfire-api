require 'test_helper'

class GroupsSetsApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
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
    post "/api/units/#{unit.id}/group_sets/#{group_set.id}/groups", with_auth_token(data, unit.main_convenor_user)
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

    # Students shouldn't be able to lock the (currently unlocked because it was just created) group, even though groups
    # within the group set are student-manageable.
    put url, with_auth_token(lock_data, group.projects.first.student)
    assert_equal 403, last_response.status
    assert_equal false, Group.find(group.id).locked

    # Main convenor should be able to lock the group.
    put url, with_auth_token(lock_data, unit.main_convenor_user)
    assert_equal 200, last_response.status
    assert_equal true, Group.find(group.id).locked

    # Students shouldn't be able to unlock the group either.
    put url, with_auth_token(unlock_data, group.projects.first.student)
    assert_equal 403, last_response.status
    assert_equal true, Group.find(group.id).locked

    # Main convenor should be able to unlock the locked group.
    put url, with_auth_token(unlock_data, unit.main_convenor_user)
    assert_equal 200, last_response.status
    assert_equal false, Group.find(group.id).locked

    group.destroy!
    group_set.destroy!
    unit.destroy!
  end

end
