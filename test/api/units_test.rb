require 'test_helper'
require "date"

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
    assert_equal JSON.parse(last_response.body)['name'], 'Intro to Social Skills'
    # Check to see if the unit's code matches what was expected
    assert_equal JSON.parse(last_response.body)['code'], 'JRRW40003'
    # Check to see if the unit's stat date matches what was expected
    assert_equal JSON.parse(last_response.body)['start_date'], '2016-05-14T00:00:00.000Z'
    # Check to see if the unit's end date matches what was expected
    assert_equal JSON.parse(last_response.body)['end_date'], '2017-05-14T00:00:00.000Z'
  end

  # GET test
  def test_units_get
    # Get response back from posting new unit
    get  "/api/units.json?auth_token=#{@auth_token}"
    # Check to see if the first unit's name matches
    assert_equal JSON.parse(last_response.body)[0]['name'], 'Introduction to Programming'
    # Check to see if the first unit's code matches
    assert_equal JSON.parse(last_response.body)[0]['code'], 'COS10001'
    # Test time zones, need to use operator for date conversion.
    # Check tart date
    assert (Time.zone.now - 6.weeks).to_date, JSON.parse(last_response.body)[0]['start_date'].to_date
    # Check end date
    assert (13.weeks.since(Time.zone.now - 6.weeks)).to_date, JSON.parse(last_response.body)[0]['end_date'].to_date

  #  assert_equal JSON.parse(last_response.body)[1]['name'], 'Object Oriented Programming'
  #  assert_equal JSON.parse(last_response.body)[1]['code'], 'COS20007'
    # assert_equal JSON.parse(last_response.body)[1]['start_date'], 'Introduction to Programming'
    # assert_equal JSON.parse(last_response.body)[1]['end_date'], 'Introduction to Programming'
  end
end
