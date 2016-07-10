require 'test_helper'
require 'date'

class UnitsTest < MiniTest::Test
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

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
  def test_units_post

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
    post_json '/api/units.json', data_to_post

    # Check to see if the unit's name matches what was expected
    actual_unit = JSON.parse(last_response.body)

    assert_equal expected_unit[:name], actual_unit['name']
    assert_equal expected_unit[:code], actual_unit['code']
    assert_equal expected_unit[:start_date], actual_unit['start_date']
    assert_equal expected_unit[:end_date], actual_unit['end_date']

    assert_equal unit_count + 1, Unit.all.count
    assert_equal expected_unit[:name], Unit.last.name
  end

  # Test POST for adding a tutorial to a unit
  def test_units_post_tutorial

  data_to_post = add_auth_token({
    tutorial: {
      day: "Monday",
      time: "2016-05-14T10:00:00+10:00",
      location: "The Moon",
      abbrev: "Boss Mode Unlocked",
      tutor_username: "rwilson"
      },
    })
    post_json '/api/units/1/tutorials.json', data_to_post

    # tutor_count = Unit.all.length

    # Let us add a tutorial to the first unit, which is Introduction to Programming (id 1)
    # post  '/api/units/1/tutorials.json',
    #       '{"tutorial":'                                    +
    #         '{'                                             +
    #         '"day":"Monday",'                               +
    #         '"time":"2016-05-14T10:00:00+10:00",'           +
    #         '"location":"The Moon",'                        +
    #         '"abbrev":"Boss Mode Unlocked",'                +
    #         '"tutor_username":"rwilson"'                    +
    #         '},'                                            +
    #       '"auth_token":' + '"' + @auth_token + '"'         +
    #       '}', "CONTENT_TYPE" => 'application/json'

    # puts JSON.parse(last_response.body)

    # # Check to see if the unit's name matches what was expected
    # assert_equal JSON.parse(last_response.body)['name'], 'Intro to Social Skills'
    # # Check to see if the unit's code matches what was expected
    # assert_equal JSON.parse(last_response.body)['code'], 'JRRW40003'
    # # Check to see if the unit's stat date matches what was expected
    # assert_equal JSON.parse(last_response.body)['start_date'], '2016-05-14T00:00:00.000Z'
    # # Check to see if the unit's end date matches what was expected
    # assert_equal JSON.parse(last_response.body)['end_date'], '2017-05-14T00:00:00.000Z'
  end
  # End POST tests
  # --------------------------------------------------------------------------- #

  # --------------------------------------------------------------------------- #
  # GET tests

  # Test GET for getting all units
  def test_units_get
    # The GET we are testing
    get "/api/units.json?auth_token=#{@auth_token}"

    actual_unit = JSON.parse(last_response.body)[0]
    expected_unit = Unit.first
    assert_equal expected_unit.name, actual_unit['name']
    assert_equal expected_unit.code, actual_unit['code']
    assert_equal expected_unit.start_date.to_date, actual_unit['start_date'].to_date
    assert_equal expected_unit.end_date.to_date, actual_unit['end_date'].to_date.to_date

    # Check last unit in Units (created in seed.db)
    actual_unit = JSON.parse(last_response.body)[1]
    expected_unit = Unit.find(2)

    assert_equal expected_unit.name, actual_unit['name']
    assert_equal expected_unit.code, actual_unit['code']
    assert_equal expected_unit.start_date.to_date, actual_unit['start_date'].to_date
    assert_equal expected_unit.end_date.to_date, actual_unit['end_date'].to_date.to_date
  end

  # Test GET for getting a specific unit by id
  def test_units_get_by_id
    # Get response back from getting a unit by id

    # Test getting the first unit with id of 1
    get  "/api/units/1.json?auth_token=#{@auth_token}"

    actual_unit = JSON.parse(last_response.body)
    expected_unit = Unit.find(1)

    # Check to see if the first unit's match
    assert_equal actual_unit['name'], expected_unit.name
    assert_equal actual_unit['code'], expected_unit.code
    assert_equal actual_unit['start_date'].to_date, expected_unit.start_date.to_date
    assert_equal actual_unit['end_date'].to_date, expected_unit.end_date.to_date

    # Get response back from getting a unit by id
    # Test getting the first unit with id of 2
    get  "/api/units/2.json?auth_token=#{@auth_token}"

    actual_unit = JSON.parse(last_response.body)
    expected_unit = Unit.find(2)

    # Check to see if the first unit's match
    assert_equal actual_unit['name'], expected_unit.name
    assert_equal actual_unit['code'], expected_unit.code
    assert_equal actual_unit['start_date'].to_date, expected_unit.start_date.to_date
    assert_equal actual_unit['end_date'].to_date, expected_unit.end_date.to_date
  end
  # End GET tests
  # --------------------------------------------------------------------------- #

  # --------------------------------------------------------------------------- #
  # PUT tests

  def test_units_put
    # users = {
    #   acain:              {first_name: "Andrew",         last_name: "Cain",                 nickname: "Macite",         role_id: Role.admin_id},
    #   jrenzella:          {first_name: "Jake",           last_name: "Renzella",             nickname: "FactoryBoy<3",   role_id: Role.convenor_id},
    #   rwilson:            {first_name: "Reuben",         last_name: "Wilson",               nickname: "FactoryGurl</3", role_id: Role.tutor_id},
    #   acummaudo:          {first_name: "Alex",           last_name: "Cummaudo",             nickname: "Doubtfire Dude", role_id: Role.student_id},
    # }
    #
    # some_tasks = 5
    # many_tasks = 10
    # some_tutorials = 2
    # many_tutorials = 4
    #
    # unit_data = {
    #   intro_prog: {
    #     code: "COS10001",
    #     name: "Introduction to Programming",
    #     convenors: [ :acain ],
    #     tutors: [
    #       { user: :acain, num: many_tutorials},
    #       { user: :rwilson, num: many_tutorials},
    #       { user: :acummaudo, num: some_tutorials},
    #       { user: :jrenzella, num: some_tutorials}
    #     ],
    #     num_tasks: some_tasks,
    #     ilos: rand(0..3),
    #     students: [ ]
    #   }
    # }
    #
    # puts unit_data[:intro_prog][:code]
    #
    # unit = Unit.create!(
    #   code: unit_data[:intro_prog][:code],
    #   name: unit_data[:intro_prog][:name],
    #   description: Populator.words(10..15),
    #   start_date: Time.zone.now  - 6.weeks,
    #   end_date: 13.weeks.since(Time.zone.now - 6.weeks)
    # )

    # unit.employ_staff(users[:acain], Role.convenor)
    # unit.save!

    # actual_unit = unit_to_update
    # expected_unit = Unit.last
    # unit_id = unit_to_update.id
    #
    # assert_equal expected_unit.name, actual_unit['name']
    # assert_equal expected_unit.code, actual_unit['code']
    # assert_equal expected_unit.start_date.to_date, actual_unit['start_date'].to_date
    # assert_equal expected_unit.end_date.to_date, actual_unit['end_date'].to_date
    #
    # data_to_put = add_auth_token({
    #   unit: {
    #     name: "Intro to Pizza Crafting",
    #     code: "PZA1011",
    #     start_date: "2017-05-14T00:00:00.000Z",
    #     end_date: "2018-05-14T00:00:00.000Z",
    #     description: "pizza lyf"
    #   },
    # })
    # put "/api/units/#{unit_id}.json", data_to_put.to_json, "CONTENT_TYPE" => 'application/json'
    #
    # actual_unit = JSON.parse(last_response.body)
    # expected_unit = data_to_put
    #
    # puts actual_unit
    #
    # assert_equal expected_unit.name, actual_unit['name']
    # assert_equal expected_unit.code, actual_unit['code']
    # assert_equal expected_unit['start_date'].to_date, actual_unit['start_date'].to_date
    # assert_equal expected_unit['end_date'].to_date, actual_unit['end_date'].to_date
  end
  # End PUT tests
  # --------------------------------------------------------------------------- #

end
