require 'test_helper'

class FocusesApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_get_focus
    u = FactoryBot.create(:unit, focus_count: 2)
    user = FactoryBot.create(:user, :student)
    u.enrol_student(user, nil)

    add_auth_header_for user: user

    # Perform the POST
    get "/api/units/#{u.id}/focuses"

    # Check status
    assert_equal 200, last_response.status, last_response.body
    assert_equal 2, last_response_body.count

    focus = u.focuses.first

    keys = %w(id title description color focus_criteria)

    assert_json_limit_keys_to_exactly keys, last_response_body.first

    response = last_response_body.first

    assert_equal focus.id, response['id']
    assert_equal focus.title, response['title']
    assert_equal focus.description, response['description']
    assert_equal focus.color, response['color']

    assert_equal focus.focus_criteria.count, response['focus_criteria'].count
    assert_equal focus.focus_criteria.first.grade, response['focus_criteria'].first['grade']
    assert_equal focus.focus_criteria.first.description, response['focus_criteria'].first['description']
  end

  def test_get_focus_needs_auth
    u = FactoryBot.create(:unit, focus_count: 2)
    user = FactoryBot.create(:user, :student)

    add_auth_header_for user: user

    # Perform the POST
    get "/api/units/#{u.id}/focuses"

    # Check status
    assert_equal 403, last_response.status, last_response.body
  end

  def test_post_focus_for_unit
    u = FactoryBot.create(:unit, focus_count: 0)

    data_to_post = {
      title: "New Focus",
      description: "New focus description",
      color: '#ffffff'
    }

    add_auth_header_for user: u.main_convenor_user

    # Perform the POST
    post_json "/api/units/#{u.id}/focuses", data_to_post

    # Check status
    assert_equal 201, last_response.status, last_response.body
    assert_equal 1, u.focuses.count
    assert_json_matches_model u.focuses.first, data_to_post, [:title, :description, :color]
  end

  def test_post_focus_for_unit_requires_auth
    u = FactoryBot.create(:unit, focus_count: 0)

    data_to_post = {
      title: "New Focus",
      description: "New focus description",
      color: '#ffffff'
    }

    user = FactoryBot.create(:user, :student)
    add_auth_header_for user: user

    # Perform the POST
    post_json "/api/units/#{u.id}/focuses", data_to_post

    # Check status
    assert_equal 403, last_response.status, last_response.body
    assert_equal 0, u.focuses.count
  end

  def test_put_focus_for_unit
    u = FactoryBot.create(:unit, focus_count: 1)

    data_to_put = {
      title: "New Focus",
      description: "New focus description",
      color: '#ffffff'
    }

    add_auth_header_for user: u.main_convenor_user

    # Perform the POST
    put_json "/api/units/#{u.id}/focuses/#{u.focuses.first.id}", data_to_put

    # Check status
    assert_equal 200, last_response.status, last_response.body
    assert_equal 1, u.focuses.count
    assert_json_matches_model u.focuses.first, data_to_put, [:title, :description, :color]
  end

  def test_put_focus_for_unit_requires_auth
    u = FactoryBot.create(:unit, focus_count: 1)

    data_to_put = {
      title: "New Focus",
      description: "New focus description",
      color: '#ffffff'
    }

    user = FactoryBot.create(:user, :student)
    add_auth_header_for user: user

    # Perform the POST
    put_json "/api/units/#{u.id}/focuses/#{u.focuses.first.id}", data_to_put

    # Check status
    assert_equal 403, last_response.status, last_response.body
  end

  def test_delete_focus_for_unit
    u = FactoryBot.create(:unit, focus_count: 1)

    add_auth_header_for user: u.main_convenor_user

    # Perform the POST
    delete_json "/api/units/#{u.id}/focuses/#{u.focuses.first.id}"

    # Check status
    assert_equal 200, last_response.status, last_response.body
    assert_equal 0, u.focuses.count
  end

  def test_delete_focus_for_unit_requires_auth
    u = FactoryBot.create(:unit, focus_count: 1)
    user = FactoryBot.create(:user, :student)

    add_auth_header_for user: user

    # Perform the POST
    delete_json "/api/units/#{u.id}/focuses/#{u.focuses.first.id}"

    # Check status
    assert_equal 403, last_response.status, last_response.body
    assert_equal 1, u.focuses.count
  end

  # Test grade criteria
  def test_put_focus_grade_criteria
    u = FactoryBot.create(:unit, focus_count: 1)

    add_auth_header_for user: u.main_convenor_user

    focus = u.focuses.first
    grade = GradeHelper::PASS_VALUE

    data_to_put = {
      criteria: "Updated Criteria",
      grade: grade
    }

    # Perform the POST
    put_json "/api/units/#{u.id}/focuses/#{focus.id}/criteria/#{grade}", data_to_put

    # Check status
    assert_equal 200, last_response.status, last_response.body
    assert_equal data_to_put[:criteria], focus.focus_criteria.where(grade: grade).first.description
  end

  def test_put_focus_grade_criteria_requires_auth
    u = FactoryBot.create(:unit, focus_count: 1)
    user = FactoryBot.create(:user, :student)

    add_auth_header_for user: user

    focus = u.focuses.first
    grade = GradeHelper::PASS_VALUE

    data_to_put = {
      criteria: "Updated Criteria",
      grade: grade
    }

    # Perform the POST
    put_json "/api/units/#{u.id}/focuses/#{focus.id}/criteria/#{grade}", data_to_put

    # Check status
    assert_equal 403, last_response.status, last_response.body
    refute_equal data_to_put[:criteria], focus.focus_criteria.where(grade: grade).first.description
  end

  def test_put_focus_grade_criteria_tests_grade_range
    u = FactoryBot.create(:unit, focus_count: 1)

    add_auth_header_for user: u.main_convenor_user

    focus = u.focuses.first
    grade = GradeHelper::FAIL_VALUE

    data_to_put = {
      criteria: "Updated Criteria",
      grade: grade
    }

    # Perform the POST
    put_json "/api/units/#{u.id}/focuses/#{focus.id}/criteria/#{grade}", data_to_put

    # Check status
    assert_equal 403, last_response.status, last_response.body
  end

end
