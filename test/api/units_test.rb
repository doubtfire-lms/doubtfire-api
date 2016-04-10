require 'test_helper'

class UnitsTest < MiniTest::Test
  include Rack::Test::Methods

  def app
    Rails.application
  end

  def setup
    @auth_token = JSON.parse((post '/api/auth.json', '{"username":"acain", "password":"password"}', "CONTENT_TYPE" => 'application/json').body)['auth_token']
  end

  # --------------------------------------------------------------------------- #
  # --- Endpoint testing for:
  # ------- /api/units.json
  # ------- POST GET

  # POST test
  def test_units_post
    # Get response back from posting new unit
    post  '/api/units.json',
          '{"unit":'                                    +
            '{'                                         +
            '"name":"Intro to Social Skills",'          +
            '"code":"JRRW40003",'                       +
            '"start_date":"2016-05-14T00:00:00.000Z",'  +
            '"end_date":"2017-05-14T00:00:00.000Z"'     +
            '},'                                        +
          '"auth_token":' + '"' + @auth_token + '"'     +
          '}', "CONTENT_TYPE" => 'application/json'
    # Check to see if the unit's name matches what was expected
    assert JSON.parse(last_response.body)['name'], 'Intro to Social Skills'
    # Check to see if the unit's code matches what was expected
    assert JSON.parse(last_response.body)['code'], 'JRRW40003'
    # Check to see if the unit's stat date matches what was expected
    assert JSON.parse(last_response.body)['start_date'], '2016-05-14T00:00:00.000Z'
    # Check to see if the unit's end date matches what was expected
    assert JSON.parse(last_response.body)['end_date'], '2017-05-14T00:00:00.000Z'
  end

  # GET test
  def test_units_get
    # Get response back from posting new unit
    get  "/api/units.json?auth_token=#{@auth_token}"
  end
end
