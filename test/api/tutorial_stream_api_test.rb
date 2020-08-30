require 'test_helper'

class TeachingPeriodTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_create_checks_uniqueness
    unit = FactoryBot.create(:unit)
    activity_type = ActivityType.first

    assert activity_type.present?

    # Add username and auth_token to Header
    add_auth_header_for(unit.main_convenor_user)

    assert_equal 0, unit.tutorial_streams.count
    post_json "/api/units/#{unit.id}/tutorial_streams", {activity_type_abbr: activity_type.abbreviation}
    assert_equal 201, last_response.status
    post_json "/api/units/#{unit.id}/tutorial_streams", {activity_type_abbr: activity_type.abbreviation}
    assert_equal 201, last_response.status

    unit.reload
    assert_equal 2, unit.tutorial_streams.count

    delete_json "/api/units/#{unit.id}/tutorial_streams/#{unit.tutorial_streams.first.abbreviation}"

    assert_equal 1, unit.tutorial_streams.count
    assert_equal 200, last_response.status
    post_json "/api/units/#{unit.id}/tutorial_streams", {activity_type_abbr: activity_type.abbreviation}
    assert_equal 201, last_response.status
  end
end
