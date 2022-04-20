require 'test_helper'

class FocusesApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
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
    put_json "/api/units/#{u.id}/focuses", data_to_put

    # Check status
    assert_equal 405, last_response.status, last_response.body
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
end
