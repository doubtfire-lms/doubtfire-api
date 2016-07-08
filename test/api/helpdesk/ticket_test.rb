require 'test_helper'
require 'date'

class TicketsTest < MiniTest::Test
  include Rack::Test::Methods
  include AuthHelper

  def app
    Rails.application
  end

  def setup
    @auth_token = get_auth_token()
  end

  # --------------------------------------------------------------------------- #
  # --- Endpoint testing for:
  # ------- /api/units.json
  # ------- POST GET PUT

  # --------------------------------------------------------------------------- #
  # POST tests

  # Test POST for creating new unit
  def test_tickets_add

    data_to_post = add_auth_token({
      unit: {
        name: "Intro to Social Skills",
        code: "JRRW40003",
        start_date: "2016-05-14T00:00:00.000Z",
        end_date: "2017-05-14T00:00:00.000Z"
      },
    })
    expected_unit = data_to_post[:unit]
    unit_count = Unit.all.length

    # The post that we will be testing.
    post '/api/units.json', data_to_post.to_json, "CONTENT_TYPE" => 'application/json'

    # Check to see if the unit's name matches what was expected
    actual_unit = JSON.parse(last_response.body)

    assert_equal expected_unit[:name], actual_unit['name']
    assert_equal expected_unit[:code], actual_unit['code']
    assert_equal expected_unit[:start_date], actual_unit['start_date']
    assert_equal expected_unit[:end_date], actual_unit['end_date']

    assert_equal unit_count + 1, Unit.all.count
    assert_equal expected_unit[:name], Unit.last.name
  end
end
