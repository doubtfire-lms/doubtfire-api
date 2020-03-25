require 'test_helper'
require 'date'

class UnitsApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  # --------------------------------------------------------------------------- #
  # --- Endpoint testing for:
  # ------- /api/units.json
  # ------- POST GET PUT

  # --------------------------------------------------------------------------- #
  # POST tests

  # Test POST for creating new unit
  def test_units_post
    data_to_post = add_auth_token(unit: {
                                    name: 'Intro to Social Skills',
                                    code: 'JRRW40003',
                                    start_date: '2016-05-14T00:00:00.000Z',
                                    end_date: '2017-05-14T00:00:00.000Z'
                                  })
    expected_unit = data_to_post[:unit]
    unit_count = Unit.all.length

    # The post that we will be testing.
    post_json '/api/units.json', data_to_post

    # Check to see if the unit's name matches what was expected
    actual_unit = last_response_body

    assert_equal expected_unit[:name], actual_unit['name']
    assert_equal expected_unit[:code], actual_unit['code']
    assert_equal expected_unit[:start_date], actual_unit['start_date']
    assert_equal expected_unit[:end_date], actual_unit['end_date']

    assert_equal unit_count + 1, Unit.all.count
    assert_equal expected_unit[:name], Unit.last.name
  end

  def create_unit
    {
      name:'Intro to Social Skills',
      code:'JRRW40003',
      start_date:'2016-05-14T00:00:00.000Z',
      end_date:'2017-05-14T00:00:00.000Z'
    }
  end

  def test_post_create_unit_custom_token(token='abcdef')
    count = Unit.all.length
    unit = create_unit

    data_to_post = {
        unit: unit,
        auth_token: token
    }

    post_json '/api/units', data_to_post
    # Successful assertion of same length again means no record was created
    assert_equal count, Unit.all.length
    assert_equal 419, last_response.status
  end

  def test_post_create_unit_empty_token
    test_post_create_unit_custom_token ''
  end

  def create_same_unit_again
    count = Unit.all.length

    data_to_post = {
        unit: create_unit,
        auth_token: auth_token
    }

    post_json '/api/units', data_to_post
    assert_equal count + 1, Unit.all.length
  
    assert_equal 201, last_response.status

    post_json '/api/units', data_to_post
    # Successful assertion of same length again means no record was created
    assert_equal count + 1, Unit.all.length
    assert_equal 500, last_response.status
  end

  def post_create_same_unit_different_name
    count = Unit.all.length
    unit = create_unit

    data_to_post = {
        unit: unit,
        auth_token: auth_token
    }

    post_json '/api/units', data_to_post
    assert_equal count + 1, Unit.all.length

    # Changes name of unit in data_to_post automatically
    unit[:name] = 'Intro to Python'

    post_json '/api/units', data_to_post
    # Successful assertion of same length again means no record was created
    assert_equal count + 1, Unit.all.length
    assert_equal 500, last_response.status
  end


  def assert_tutorial_model_response(response, expected)
    expected = expected.as_json

    # Can't use assert_json_matches_model as keys differ
    assert_equal response[:meeting_day], expected[:day]
    assert_equal response[:meeting_time], expected[:time]
    assert_equal response[:location], expected[:location]
    assert_equal response[:abbrev], expected[:abbrev]
  end


  def test_addtutorial_to_unit
    count_tutorials = Tutorial.all.length

    tutorial = {
      unit_id: '1',
      tutor_id: User.first.id,
      campus_id: Campus.first.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial,
      auth_token: auth_token
    }

    # perform the post
    post_json '/api/tutorials', data_to_post
    assert_equal 201, last_response.status, last_response_body
    # Check there is a new tutorial
    assert_equal count_tutorials + 1, Tutorial.all.length, last_response_body
    assert_tutorial_model_response last_response_body, tutorial
  end

  # End POST tests
  # --------------------------------------------------------------------------- #

  # --------------------------------------------------------------------------- #
  # GET tests

  # Test GET for getting all units
  #def test_units_get
    # The GET we are testing
   # get with_auth_token '/api/units'

   # actual_unit = last_response_body[0]
    #expected_unit = Unit.first
   # assert_equal expected_unit.name, actual_unit['name']
   # assert_equal expected_unit.code, actual_unit['code']
   # assert_equal expected_unit.start_date.to_date, actual_unit['start_date'].to_date
    #assert_equal expected_unit.end_date.to_date, actual_unit['end_date'].to_date.to_date

    # Check last unit in Units (created in seed.db)
   # actual_unit = last_response_body[1]
    #expected_unit = Unit.find(2)

    #assert_equal expected_unit.name, actual_unit['name']
    #assert_equal expected_unit.code, actual_unit['code']
    #assert_equal expected_unit.start_date.to_date, actual_unit['start_date'].to_date
    #assert_equal expected_unit.end_date.to_date, actual_unit['end_date'].to_date.to_date
  #end

  # Test GET for getting a specific unit by id
  def test_units_get_by_id
    # Test getting the first unit with id of 1
    get with_auth_token '/api/units/1'

    actual_unit = last_response_body
    expected_unit = Unit.find(1)

    # Check to see if the first unit's match
    assert_equal actual_unit['name'], expected_unit.name
    assert_equal actual_unit['code'], expected_unit.code
    assert_equal actual_unit['start_date'].to_date, expected_unit.start_date.to_date
    assert_equal actual_unit['end_date'].to_date, expected_unit.end_date.to_date

    # Get response back from getting a unit by id
    # Test getting the first unit with id of 2
    get with_auth_token '/api/units/2'

    actual_unit = last_response_body
    expected_unit = Unit.find(2)

    # Check to see if the first unit's match
    assert_equal actual_unit['name'], expected_unit.name
    assert_equal actual_unit['code'], expected_unit.code
    assert_equal actual_unit['start_date'].to_date, expected_unit.start_date.to_date
    assert_equal actual_unit['end_date'].to_date, expected_unit.end_date.to_date
  end

  def test_units_get_has_streams
    expected_unit = FactoryBot.create(:unit, with_students: false, stream_count: 2)

    # Get the unit...
    get with_auth_token "/api/units/#{expected_unit.id}"

    actual_unit = last_response_body

    # Check to see if the first unit's match
    assert_equal actual_unit['name'], expected_unit.name
    assert_equal actual_unit['code'], expected_unit.code
    assert_equal actual_unit['start_date'].to_date, expected_unit.start_date.to_date
    assert_equal actual_unit['end_date'].to_date, expected_unit.end_date.to_date

    assert_equal 2, actual_unit['tutorial_streams'].count

    expected_unit = FactoryBot.create(:unit, with_students: false, stream_count: 3)

    # Get the unit...
    get with_auth_token "/api/units/#{expected_unit.id}"

    actual_unit = last_response_body

    # Check to see if the first unit's match
    assert_equal actual_unit['name'], expected_unit.name
    assert_equal actual_unit['code'], expected_unit.code
    assert_equal actual_unit['start_date'].to_date, expected_unit.start_date.to_date
    assert_equal actual_unit['end_date'].to_date, expected_unit.end_date.to_date

    assert_equal 3, actual_unit['tutorial_streams'].count
  end

  #Test GET for getting the unit details of current user
  def test_units_current
    get with_auth_token '/api/units'
    assert_equal 200, last_response.status
  end
  

  #Test PUT for updating unit details with valid id
  def test_units_put
    original = FactoryBot.create(:unit, with_students: false)
    unit={}
    unit['name'] = 'Intro to python'
    unit['code'] = 'JRSW40004'
    unit['description'] = 'new language'
    unit['start_date'] = '2018-12-14T00:00:00.000Z'
    unit['end_date']='2019-05-14T00:00:00.000Z'
    unit['active'] = false
    unit['auto_apply_extension_before_deadline'] = false
    unit['send_notifications'] = false
    data_to_put = {
      unit:unit,
      auth_token: auth_token
    }
    put_json '/api/units/1', data_to_put
    assert_equal 200, last_response.status

    assert_json_matches_model Unit.first, unit, %w( name code description start_date end_date active auto_apply_extension_before_deadline send_notifications )
  end

  #Test PUT for updating unit details with empty name
  def test_put_update_unit_empty_name
    unit = Unit.first
    unit[:name] = ''

    data_to_put = {
        unit: unit,
        auth_token: auth_token
    }

    put_json '/api/units/1', data_to_put
    assert_equal 400, last_response.status
  end

  #Test PUT for updating unit details with invalid id
  def test_put_update_unit_invalid_id
    data_to_put = {
        unit: { name: 'test'},
        auth_token: auth_token
    }

    put_json '/api/units/12', data_to_put
    assert_equal 404, last_response.status
  end

  # Test GET for getting a specific unit by invalid id
  def test_fail_units_get_by_id
    get with_auth_token '/api/units/12'
    assert_equal 404, last_response.status
  end

  def test_put_update_unit_custom_token(token='abcdef')
    unit= Unit.first
    data_to_put = {
        unit: unit,
        auth_token:token
    }

    put_json '/api/units/1', data_to_put
    assert_equal 419, last_response.status
  end

  def test_put_update_unit_empty_token
    test_put_update_unit_custom_token ''
  end

  # End GET tests
  # --------------------------------------------------------------------------- #

  # --------------------------------------------------------------------------- #
  # PUT tests

  def test_update_main_convenor
    unit = FactoryBot.create :unit, with_students: false, task_count: 0, tutorials: 0, outcome_count: 0, staff_count: 0, campus_count: 0

    convenor_user = FactoryBot.create :user, :convenor
    convenor_user_role = unit.employ_staff convenor_user, Role.convenor

    data_to_put = {
      unit: {
        main_convenor_id: convenor_user_role.id
      }
    }

    put_json with_auth_token("/api/units/#{unit.id}", unit.main_convenor_user), data_to_put

    unit.reload
    assert_equal 200, last_response.status
    assert_equal convenor_user_role.id, unit.main_convenor_id
  end

  #def test_units_put
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
    # actual_unit = last_response_body
    # expected_unit = data_to_put
    #
    # puts actual_unit
    #
    # assert_equal expected_unit.name, actual_unit['name']
    # assert_equal expected_unit.code, actual_unit['code']
    # assert_equal expected_unit['start_date'].to_date, actual_unit['start_date'].to_date
    # assert_equal expected_unit['end_date'].to_date, actual_unit['end_date'].to_date
  #end
  # End PUT tests
  # --------------------------------------------------------------------------- #
 #end
end
