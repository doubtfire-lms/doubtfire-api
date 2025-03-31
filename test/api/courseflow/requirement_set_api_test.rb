require "test_helper"

class RequirementSetTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_get_all_requirement_sets
    requirement_set1 = FactoryBot.create(:requirement_set)
    requirement_set2 = FactoryBot.create(:requirement_set)
    add_auth_header_for(user: User.first)
    get "/api/requirementset"
    assert_equal 200, last_response.status
    assert_equal 2, JSON.parse(last_response.body).size
  ensure
    requirement_set1.destroy
    requirement_set2.destroy
  end

  def test_get_requirement_set_by_group_id
    test_id = 101
    requirement_set = FactoryBot.create(:requirement_set, requirementSetGroupId: test_id)
    add_auth_header_for(user: User.first)
    get "/api/requirementset/requirementSetGroupId/#{test_id}"
    assert_equal 200, last_response.status
  ensure
    requirement_set.destroy
  end

  def test_create_requirement_set
    data_to_post = { requirementSetGroupId: 101, description: 'Test', unitId: 101, requirementId: 101 }
    add_auth_header_for(user: User.first)
    post_json "/api/requirementset", data_to_post
    assert_equal 201, last_response.status
  end

  def test_update_requirement_set
    requirement_set = FactoryBot.create(:requirement_set, requirementSetGroupId: 101, description: 'Test', unitId: 101, requirementId: 101)
    data_to_put = { requirementSetGroupId: 102, description: 'Test2', unitId: 102, requirementId: 102 }
    add_auth_header_for(user: User.first)
    put_json "/api/requirementset/requirementSetId/#{requirement_set.id}", data_to_put
    assert_equal 200, last_response.status
  ensure
    requirement_set.destroy
  end

  def test_delete_requirement_set
    requirement_set = FactoryBot.create(:requirement_set, requirementSetGroupId: 101, description: 'Test', unitId: 101, requirementId: 101)
    add_auth_header_for(user: User.first)
    delete "/api/requirementset/requirementSetId/#{requirement_set.id}"
    assert_equal 0, Courseflow::RequirementSet.where(id: requirement_set.id).count
  ensure
    requirement_set.destroy
  end

  def test_delete_requirement_set_unauthorised
    requirement_set = FactoryBot.create(:requirement_set, requirementSetGroupId: 101, description: 'Test', unitId: 101, requirementId: 101)
    delete "/api/requirementset/requirementSetId/#{requirement_set.id}"
    assert_equal 419, last_response.status
  ensure
    requirement_set.destroy
  end

  def test_delete_requrement_set_invalid_id
    add_auth_header_for(user: User.first)
    delete "/api/requirementset/requirementSetId/999"
    assert_equal 404, last_response.status
  end

end
