require 'test_helper'

class RequirementApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  setup do
    @unit   = FactoryBot.create(:unit)
    @course = FactoryBot.create(:course)
    @attrs  = {
      unitId: @unit.id,
      courseId: @course.id,
      type: 'count',
      category: 'prerequisite',
      description: 'Must complete SIT102 first',
      minimum: 1,
      maximum: 1,
      requirementSetGroupId: 1
    }
    add_auth_header_for user: User.first
  end

  def teardown
    Courseflow::Requirement.destroy_all
    @unit.destroy
    @course.destroy
  end

  def test_get_all_requirements
    req = FactoryBot.create(:requirement, @attrs)
    get "/api/requirement"
    assert_equal 200, last_response.status
  ensure
    req.destroy
  end

  def test_get_requirements_by_unit
    req = FactoryBot.create(:requirement, @attrs)
    get "/api/requirement/unitId/#{@unit.id}"
    assert_equal 200, last_response.status
  ensure
    req.destroy
  end

  def test_get_requirements_by_course
    req = FactoryBot.create(:requirement, @attrs)
    get "/api/requirement/courseId/#{@course.id}"
    assert_equal 200, last_response.status
  ensure
    req.destroy
  end

  def test_create_requirement
    post_json "/api/requirement", @attrs
    assert_equal 201, last_response.status
    assert_equal 'prerequisite', last_response_body['category']
  end

  def test_update_requirement
    req = FactoryBot.create(:requirement, @attrs)
    put_json "/api/requirement/#{req.id}", description: 'Updated'
    assert_equal 200, last_response.status
    assert_equal 'Updated', last_response_body['description']
  ensure
    req.destroy
  end

  def test_delete_requirement
    req = FactoryBot.create(:requirement, @attrs)
    delete "/api/requirement/#{req.id}"
    assert_equal 204, last_response.status
    assert_not Courseflow::Requirement.exists?(req.id)
  end

  def test_unauthorized_create_requirement
    clear_auth_header
    post_json "/api/requirement", @attrs
    assert_equal 419, last_response.status
  end
end
