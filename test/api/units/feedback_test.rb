require 'test_helper'

class FeedbackTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_get_awaiting_feedback
    random_unitrole = UnitRole.tutors.sample
    unit = random_unitrole.unit
    user = random_unitrole.user

    expected_response = unit.tasks_awaiting_feedback(User.first)

    get with_auth_token "/api/units/#{unit.id}/feedback", user

    assert_equal 200, last_response.status

    # check each is the same
    last_response_body.zip(expected_response).each do |response, expected|
      assert_json_matches_model response, expected, ['id']
    end
  end
end
