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
  # ------- POST GET PUT

  # --------------------------------------------------------------------------- #
  # POST tests

  # Test POST for creating new unit
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
  # End POST tests
  # --------------------------------------------------------------------------- #

  # --------------------------------------------------------------------------- #
  # GET tests

  # Test GET for getting all units
  def test_units_get
    # Get response back from posting new unit
    # The GET we are testing
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

    # Check second unit in Units
    # Check Name of second unit created
    assert_equal JSON.parse(last_response.body)[1]['name'], 'Game Programming'
    # Check code of second unit created
    assert_equal JSON.parse(last_response.body)[1]['code'], 'COS30243'
    # Check start date
    assert (Time.zone.now - 6.weeks).to_date == JSON.parse(last_response.body)[1]['start_date'].to_date
    # Check end date
    assert (13.weeks.since(Time.zone.now - 6.weeks)).to_date == JSON.parse(last_response.body)[1]['end_date'].to_date
  end

  def test_units_put

    # First post a new unit and test it
    post  '/api/units.json',
          '{"unit":'                                    +
            '{'                                         +
            '"name":"Intro to Ethnic Studies",'         +
            '"code":"ETS1011",'                         +
            '"start_date":"2016-05-14T00:00:00.000Z",'  +
            '"end_date":"2017-05-14T00:00:00.000Z"'     +
            '},'                                        +
          '"auth_token":' + '"' + @auth_token + '"'     +
          '}', "CONTENT_TYPE" => 'application/json'

    unit_id = JSON.parse(last_response.body)['id']

    assert_equal JSON.parse(last_response.body)['name'], 'Intro to Ethnic Studies'
    assert_equal JSON.parse(last_response.body)['code'], 'ETS1011'
    assert JSON.parse(last_response.body)['start_date'].to_date == '2016-05-14T00:00:00.000Z'.to_date
    assert JSON.parse(last_response.body)['end_date'].to_date == '2017-05-14T00:00:00.000Z'.to_date

    # put  "/api/units/1.json?auth_token=#{@auth_token}"

    put  "/api/units/#{unit_id}.json",
          '{"unit":'                                    +
            '{'                                         +
            '"name":"Intro to Pizza Crafting",'         +
            '"code":"PZA1011",'                         +
            '"start_date":"2017-05-14T00:00:00.000Z",'  +
            '"end_date":"2018-05-14T00:00:00.000Z"'     +
            '},'                                        +
          '"auth_token":' + '"' + @auth_token + '"'     +
          '}', "CONTENT_TYPE" => 'application/json'
    # Check second unit in Units
    # Check Name of second unit created
    assert_equal JSON.parse(last_response.body)['name'], 'Intro to Pizza Crafting'
    assert_equal JSON.parse(last_response.body)['code'], 'PZA1011'
    assert JSON.parse(last_response.body)['start_date'].to_date == '2017-05-14T00:00:00.000Z'.to_date
    assert JSON.parse(last_response.body)['end_date'].to_date == '2018-05-14T00:00:00.000Z'.to_date

  end

  # Test GET for getting a specific unit by id
  def test_units_get_by_id
    # Get response back from getting a unit by id

    # Test getting the first unit with id of 1
    get  "/api/units/1.json?auth_token=#{@auth_token}"

    # Check to see if the first unit's name matches
    assert_equal JSON.parse(last_response.body)['name'], 'Introduction to Programming'
    # Check to see if the first unit's code matches
    assert_equal JSON.parse(last_response.body)['code'], 'COS10001'
    # Test time zones, need to use operator for date conversion.
    # Check tart date
    assert (Time.zone.now - 6.weeks).to_date, JSON.parse(last_response.body)['start_date'].to_date
    # Check end date
    assert (13.weeks.since(Time.zone.now - 6.weeks)).to_date, JSON.parse(last_response.body)['end_date'].to_date

    # Get response back from getting a unit by id
    # Test getting the first unit with id of 2
    get  "/api/units/2.json?auth_token=#{@auth_token}"

    # Check to see if the first unit's name matches
    assert_equal JSON.parse(last_response.body)['name'], 'Game Programming'
    # Check to see if the first unit's code matches
    assert_equal JSON.parse(last_response.body)['code'], 'COS30243'
    # Test time zones, need to use operator for date conversion.
    # Check tart date
    assert (Time.zone.now - 6.weeks).to_date, JSON.parse(last_response.body)['start_date'].to_date
    # Check end date
    assert (13.weeks.since(Time.zone.now - 6.weeks)).to_date, JSON.parse(last_response.body)['end_date'].to_date
  end
  # End GET tests
  # --------------------------------------------------------------------------- #

end
