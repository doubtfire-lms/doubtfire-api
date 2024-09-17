require 'test_helper'

class TutorialsTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  # --------------------------------------------------------------------------- #
  # --- Endpoint testing for:
  # ------- /api/tutorials
  # ------- POST PUT DELETE

  # --------------------------------------------------------------------------- #

  #####----------POST tests - Create tutorial----------#####

  def assert_tutorial_model_response(response, expected)
    assert_json_matches_model expected, response, %w(id meeting_day meeting_time meeting_location abbreviation campus_id capacity)
  end

  # Testing for successful POST creations
  def test_unit_main_convenor_can_post_tutorials
    # Create dummy attributes for the tutorial
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.first

    tutorial = {
      unit_id: unit.id,
      tutor_id: tutor.id,
      campus_id: campus.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial
    }

    # Number of tutorials before POST
    number_of_tutorials = Tutorial.all.length

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    # perform the POST with the unit main convenor auth token
    post_json '/api/tutorials', data_to_post

    # Check for successful request
    assert_equal 201, last_response.status

    # Check if there is a new tutorial
    assert_equal Tutorial.all.length, number_of_tutorials + 1

    # Check returned details match as expected
    tutorial['id'] = Tutorial.last.id
    assert_tutorial_model_response last_response_body, tutorial
  end

  def test_unit_admin_can_post_tutorials
    # Create dummy attributes for the tutorial
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.first

    tutorial = {
      unit_id: unit.id,
      tutor_id: tutor.id,
      campus_id: campus.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial
    }

    # Create and add an admin into the unit
    admin = FactoryBot.create(:user, :admin)
    unit.employ_staff admin, Role.admin
    admin.reload

    # Number of tutorials before POST
    number_of_tutorials = Tutorial.all.length

    # Add username and auth_token to Header
    add_auth_header_for(user: admin)

    # perform the post with the admin auth token
    post_json '/api/tutorials', data_to_post

    # Check for successful request
    assert_equal 201, last_response.status

    # Check if there is a new tutorial
    assert_equal Tutorial.all.length, number_of_tutorials + 1

    # Check if the returned details match as expected
    tutorial['id'] = Tutorial.last.id
    assert_tutorial_model_response last_response_body, tutorial
  end

  def test_post_tutorial_with_string_meeting_time
    # Create dummy attributes for the tutorial
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.second

    tutorial = {
      unit_id: unit.id,
      tutor_id: tutor.id,
      campus_id: campus.id,
      capacity: 10,
      abbreviation: 'La011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: 'string'
    }

    data_to_post = {
      tutorial: tutorial
    }
    # Number of tutorials before POST
    number_of_tutorials = Tutorial.all.length

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    # perform the post with the unit main convenor auth token
    post_json '/api/tutorials', data_to_post

    # Check if the POST get through
    assert_equal 201, last_response.status

    # Check if there is a new creation
    assert_equal number_of_tutorials + 1, Tutorial.all.length

    # Check if the returned details match as expected
    assert_tutorial_model_response last_response_body, Tutorial.last
  end

  # Testing for POST failures
  def test_post_tutorial_with_incorrect_auth_token
    # Create dummy attributes for the tutorial
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.first

    tutorial = {
      unit_id: unit.id,
      tutor_id: tutor.id,
      campus_id: campus.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial
    }

    # Add username and auth_token to Header
    add_auth_header_for(auth_token: 'Incorrect_Auth_Token', username: 'aadmin')

    # Number of tutorials before POST
    number_of_tutorials = Tutorial.all.length

    # perform the POST with incorrect auth token
    post_json '/api/tutorials', data_to_post

    # Check for authentication failure
    assert_equal 419, last_response.status

    # Check if there is no new tutorial
    assert_equal Tutorial.all.length, number_of_tutorials
  end

  def test_post_tutorial_with_empty_auth_token
    # Create dummy attributes for the tutorial
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.first

    tutorial = {
      unit_id: unit.id,
      tutor_id: tutor.id,
      campus_id: campus.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial
    }

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    #Override header for empty auth_token
    header 'auth_token',''

    # Number of tutorials before POST
    number_of_tutorials = Tutorial.all.length

    # perform the POST with empty auth token
    post_json '/api/tutorials', data_to_post

    # Check for authentication failure
    assert_equal 419, last_response.status

    # Check if there is no new tutorial
    assert_equal Tutorial.all.length, number_of_tutorials
  end

  def test_post_tutorial_with_string_unit_id
    # Create dummy attributes for the tutorial
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.first

    tutorial = {
      unit_id: 'string',
      tutor_id: tutor.id,
      campus_id: campus.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial
    }

    # Number of tutorials before POST
    number_of_tutorials = Tutorial.all.length

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    # perform the POST with the unit main convenor auth token
    post_json '/api/tutorials', data_to_post

    # Check for error in creation
    assert_equal 400, last_response.status
    assert_equal 'tutorial[unit_id] is invalid', last_response_body['error']

    # Check if there is no new tutorial
    assert_equal Tutorial.all.length, number_of_tutorials
  end

  def test_post_tutorial_with_string_tutor_id
    # Create dummy attributes for the tutorial
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.first

    tutorial = {
      unit_id: unit.id,
      tutor_id: 'string',
      campus_id: campus.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial
    }

    # Number of tutorials before POST
    number_of_tutorials = Tutorial.all.length

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    # perform the post with the unit main convenor auth token
    post_json '/api/tutorials', data_to_post

    # Check for error in creation
    assert_equal 400, last_response.status
    assert_equal 'tutorial[tutor_id] is invalid', last_response_body['error']

    # Check if there is no new tutorial
    assert_equal Tutorial.all.length, number_of_tutorials
  end

  def test_post_existing_values
    # Create dummy attributes for the tutorial
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.first

    tutorial = {
      unit_id: unit.id,
      tutor_id: tutor.id,
      campus_id: campus.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial
    }

    # Number of tutorials before the first POST
    number_of_tutorials = Tutorial.all.length

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    # perform the first POST with the unit main convenor auth token
    post_json '/api/tutorials', data_to_post

    # Check if the POST get through
    assert_equal 201, last_response.status

    # Check if there is a new tutorial after the first POST
    assert_equal Tutorial.all.length, number_of_tutorials + 1

    # Number of tutorials before the second POST
    number_of_tutorials = Tutorial.all.length

    # Create and add an admin into the unit
    admin = FactoryBot.create(:user, :admin)
    unit.employ_staff admin, Role.admin
    admin.reload

    # Add username and auth_token to Header
    add_auth_header_for(user: admin)

    # perform the second POST of duplicate values with an admin auth token
    post_json '/api/tutorials', data_to_post

    # Check for error
    assert_equal 400, last_response.status
    assert last_response_body['error'].include? 'Validation failed'

    # Check if there is no new tutorial after the second POST
    assert_equal Tutorial.all.length, number_of_tutorials
  end

  def test_post_tutorial_with_empty_unit_id
    # Create dummy attributes for the tutorial
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.first

    tutorial = {
      unit_id: '',
      tutor_id: tutor.id,
      campus_id: campus.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial
    }

    # Number of tutorials before POST
    number_of_tutorials = Tutorial.all.length

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    # perform the POST with the unit main convenor auth token
    post_json '/api/tutorials', data_to_post

    # Check for error in creation
    assert_equal 404, last_response.status
    assert_equal 'Unable to find requested Unit', last_response_body['error']

    # Check if there is no new tutorial
    assert_equal Tutorial.all.length, number_of_tutorials
  end

  def test_post_tutorial_with_empty_tutor_id
    # Create dummy attributes for the tutorial
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.first

    tutorial = {
      unit_id: unit.id,
      tutor_id: '',
      campus_id: campus.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial
    }

    # Number of tutorials before POST
    number_of_tutorials = Tutorial.all.length

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    # perform the POST with the unit main convenor auth token
    post_json '/api/tutorials', data_to_post

    # Check for error in creation
    assert_equal 404, last_response.status
    assert_equal 'Unable to find requested User', last_response_body['error']

    # Check if there is no new tutorial
    assert_equal Tutorial.all.length, number_of_tutorials
  end

  def test_post_tutorial_with_empty_abbreviation
    # Create dummy attributes for the tutorial
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.first

    tutorial = {
      unit_id: unit.id,
      tutor_id: tutor.id,
      campus_id: campus.id,
      capacity: 10,
      abbreviation: '',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial
    }

    # Number of tutorials before POST
    number_of_tutorials = Tutorial.all.length

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    # perform the post with the unit main convenor auth token
    post_json '/api/tutorials', data_to_post

    # Check for error in creation
    assert_equal 400, last_response.status
    assert last_response_body['error'].include? 'tutorial[abbreviation] is empty'

    # Check if there is no new tutorial
    assert_equal Tutorial.all.length, number_of_tutorials
  end

  def test_post_tutorial_with_empty_meeting_location
    # Create dummy attributes for the tutorial
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.first

    tutorial = {
      unit_id: unit.id,
      tutor_id: tutor.id,
      campus_id: campus.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: '',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial
    }

    # Number of tutorials before POST
    number_of_tutorials = Tutorial.all.length

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    # perform the POST with the unit main convenor auth token
    post_json '/api/tutorials', data_to_post

    # Check for error in creation
    assert_equal 400, last_response.status
    assert last_response_body['error'].include? 'meeting_location] is empty'

    # Check if there is no new tutorial
    assert_equal Tutorial.all.length, number_of_tutorials
  end

  def test_post_tutorial_with_empty_meeting_day
    # Create dummy attributes for the tutorial
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.first

    tutorial = {
      unit_id: unit.id,
      tutor_id: tutor.id,
      campus_id: campus.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: '',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial
    }

    # Number of tutorials before POST
    number_of_tutorials = Tutorial.all.length

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    # perform the POST with the unit main convenor auth token
    post_json '/api/tutorials', data_to_post

    # Check for error in creation
    assert_equal 400, last_response.status
    assert last_response_body['error'].include? 'meeting_day] is empty'

    # Check if there is no new tutorial
    assert_equal Tutorial.all.length, number_of_tutorials
  end

  def test_post_tutorial_with_empty_meeting_time
    # Create dummy attributes for the tutorial
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.first

    tutorial = {
      unit_id: unit.id,
      tutor_id: tutor.id,
      campus_id: campus.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: ''
    }

    data_to_post = {
      tutorial: tutorial
    }

    # Number of tutorials before POST
    number_of_tutorials = Tutorial.all.length

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    # perform the post with the unit main convenor auth token
    post_json '/api/tutorials', data_to_post

    # Check for error in creation
    assert_equal 400, last_response.status
    assert last_response_body['error'].include? 'meeting_time] is empty'

    # Check if there is no new tutorial
    assert_equal Tutorial.all.length, number_of_tutorials
  end

  def test_tutor_cannot_post_tutorials
    # Create dummy attributes for a tutorial to post
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.first

    tutorial = {
      unit_id: unit.id,
      tutor_id: tutor.id,
      campus_id: campus.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial,
    }

    # Create and add a dedicated tutor into the unit
    dedicated_tutor = FactoryBot.create(:user, :tutor)
    unit.employ_staff dedicated_tutor, Role.tutor
    dedicated_tutor.reload

    # Number of tutorials before POST
    number_of_tutorials = Tutorial.all.length

    # Add username and auth_token to Header
    add_auth_header_for(user: dedicated_tutor)

    # perform the POST with the unit dedicated tutor auth token
    post_json '/api/tutorials', data_to_post

    # Check for failing due to no authorisation
    assert_equal 403, last_response.status

    # Check there is no new tutorial
    assert_equal Tutorial.all.length, number_of_tutorials
  end

  def test_student_cannot_post_tutorials
    # Create dummy attributes for a tutorial to post
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.first

    tutorial = {
      unit_id: unit.id,
      tutor_id: tutor.id,
      campus_id: campus.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_post = {
      tutorial: tutorial,
    }
    number_of_tutorials = Tutorial.all.length

    # The student user to perform the POST
    student = unit.active_projects.first.student

    # Add username and auth_token to Header
    add_auth_header_for(user: student)

    # perform the POST with a student auth token
    post_json '/api/tutorials', data_to_post

    # Check for failing due to no authorisation
    assert_equal 403, last_response.status

    # Check there is no new tutorial
    assert_equal Tutorial.all.length, number_of_tutorials
  end

  #####----------PUT tests - Update a tutorial----------#####

  # Testing for successful PUT operations
  def test_admin_can_put_tutorials
    # Create a dummy tutorial
    tutorial_old = FactoryBot.create(:tutorial)

    # Create dummy attributes for a new tutorial
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.first

    tutorial = {
      id: tutorial_old.id,
      unit_id: unit.id,
      tutor_id: tutor.id,
      campus_id: campus.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_put = {
      tutorial: tutorial
    }

    # Create and add an admin into the unit
    admin = FactoryBot.create(:user, :admin)
    unit.employ_staff admin, Role.admin
    admin.reload

    # Add username and auth_token to Header
    add_auth_header_for(user: admin)

    # perform the PUT with a unit admin auth token
    put_json "/api/tutorials/#{tutorial_old.id}", data_to_put

    # Check for successful request
    assert_equal 200, last_response.status

    # Check details match as expected
    tutorial_old.reload
    assert_tutorial_model_response last_response_body, tutorial_old
    assert_tutorial_model_response last_response_body, tutorial
  end

  def test_put_tutorials_with_empty_abbreviation
    # Create a dummy tutorial
    tutorial_old = FactoryBot.create(:tutorial)

    # Create dummy attributes for a new tutorial
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.first

    tutorial = {
      id: tutorial_old.id,
      unit_id: unit.id,
      tutor_id: tutor.id,
      campus_id: campus.id,
      capacity: 10,
      abbreviation: '',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_put = {
      tutorial: tutorial
    }

    # Create and add an admin into the unit
    admin = FactoryBot.create(:user, :admin)
    unit.employ_staff admin, Role.admin
    admin.reload

    # Add username and auth_token to Header
    add_auth_header_for(user: admin)

    # perform the put with an admin auth token
    put_json "/api/tutorials/#{tutorial_old.id}", data_to_put

    # Check for successful request
    assert_equal 200, last_response.status

    # Check details match as expected
    tutorial_old.reload
    assert_tutorial_model_response last_response_body, tutorial_old
    assert_tutorial_model_response last_response_body, tutorial
  end

  def test_tutorials_put_empty_meeting_location
    # Create a dummy tutorial
    tutorial_old = FactoryBot.create(:tutorial)

    # Create dummy attributes for a new tutorial
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.first

    tutorial = {
      id: tutorial_old.id,
      unit_id: unit.id,
      tutor_id: tutor.id,
      campus_id: campus.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: '',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_put = {
      tutorial: tutorial
    }

    # Create and add an admin into the unit
    admin = FactoryBot.create(:user, :admin)
    unit.employ_staff admin, Role.admin
    admin.reload

    # Add username and auth_token to Header
    add_auth_header_for(user: admin)

    # perform the put with an admin auth token
    put_json "/api/tutorials/#{tutorial_old.id}", data_to_put

    # Check for successful request
    assert_equal 200, last_response.status

    # Check details match as expected
    tutorial_old.reload
    assert_tutorial_model_response last_response_body, tutorial_old
    assert_tutorial_model_response last_response_body, tutorial
  end

  def test_put_tutorials_with_empty_meeting_day
    # Create a dummy tutorial
    tutorial_old = FactoryBot.create(:tutorial)

    # Create dummy attributes for a new tutorial
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.first

    tutorial = {
      id: tutorial_old.id,
      unit_id: unit.id,
      tutor_id: tutor.id,
      campus_id: campus.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: '',
      meeting_time: '18:00'
    }

    data_to_put = {
      tutorial: tutorial
    }

    # Create and add an admin into the unit
    admin = FactoryBot.create(:user, :admin)
    unit.employ_staff admin, Role.admin
    admin.reload

    # Add username and auth_token to Header
    add_auth_header_for(user: admin)

    # perform the put with an admin auth token
    put_json "/api/tutorials/#{tutorial_old.id}", data_to_put

    # Check for successful request
    assert_equal 200, last_response.status

    # Check details match as expected
    tutorial_old.reload
    assert_tutorial_model_response last_response_body, tutorial_old
    assert_tutorial_model_response last_response_body, tutorial
  end

  def test_tutorials_put_empty_meeting_time
    # Create a dummy tutorial
    tutorial_old = FactoryBot.create(:tutorial)

    # Create dummy attributes for a new tutorial
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.first

    tutorial = {
      id: tutorial_old.id,
      unit_id: unit.id,
      tutor_id: tutor.id,
      campus_id: campus.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: ''
    }

    data_to_put = {
      tutorial: tutorial
    }

    # Create and add an admin into the unit
    admin = FactoryBot.create(:user, :admin)
    unit.employ_staff admin, Role.admin
    admin.reload

    # Add username and auth_token to Header
    add_auth_header_for(user: admin)

    # perform the PUT with a unit admin auth token
    put_json "/api/tutorials/#{tutorial_old.id}", data_to_put

    # Check for successful request
    assert_equal 200, last_response.status

    # Check details match as expected
    tutorial_old.reload
    assert_tutorial_model_response last_response_body, tutorial_old
    assert_tutorial_model_response last_response_body, tutorial
  end

  # Testing for PUT failures
  def test_put_tutorials_with_empty_auth_token
    # Create a dummy tutorial
    tutorial_old = FactoryBot.create(:tutorial)

    # Create dummy attributes for the tutorial
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.first

    tutorial = {
      unit_id: unit.id,
      tutor_id: tutor.id,
      campus_id: campus.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_put = {
      tutorial: tutorial
    }

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    #Override header for empty auth_token
    header 'auth_token',''

    # perform the PUT with empty auth token
    put_json "/api/tutorials/#{tutorial_old.id}", data_to_put

    # Check the request fails
    assert_equal 419, last_response.status
  end

  def test_put_tutorials_with_incorrect_auth_token
    # Create a dummy tutorial
    tutorial_old = FactoryBot.create(:tutorial)

    # Create dummy attributes for the tutorial
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.first

    tutorial = {
      unit_id: unit.id,
      tutor_id: tutor.id,
      campus_id: campus.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_put = {
      tutorial: tutorial
    }

    # Add username and auth_token to Header
    add_auth_header_for(username: 'aadmin', auth_token: 'Incorrect auth token')

    # perform the PUT with incorrect auth token
    put_json "/api/tutorials/#{tutorial_old.id}", data_to_put

    # Check the request fails
    assert_equal 419, last_response.status
  end

  def test_main_convenor_cannot_replace_tutorials
    # Create a dummy tutorial
    tutorial_old = FactoryBot.create(:tutorial)

    # Create dummy attributes for the tutorial
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.first

    tutorial = {
      unit_id: unit.id,
      tutor_id: tutor.id,
      campus_id: campus.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_put = {
      tutorial: tutorial
    }

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    # perform the put with the unit main convenor auth token
    put_json "/api/tutorials/#{tutorial_old.id}", data_to_put

    # Check the request fails
    assert_equal 403, last_response.status
  end

  def test_tutor_cannot_replace_tutorial
     # Create a dummy tutorial
     tutorial_old = FactoryBot.create(:tutorial)

     # Create dummy attributes for the tutorial
     campus = FactoryBot.create(:campus)
     unit = FactoryBot.create(:unit)
     tutor = unit.tutors.first

    tutorial = {
      unit_id: unit.id,
      tutor_id: tutor.id,
      campus_id: campus.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_put = {
      tutorial: tutorial
    }

    # Create and add a dedicated tutor into the unit
    dedicated_tutor = FactoryBot.create(:user, :tutor)
    unit.employ_staff dedicated_tutor, Role.tutor
    dedicated_tutor.reload

    # Add username and auth_token to Header
    add_auth_header_for(user: dedicated_tutor)

    # perform the put with the dedicated tutor auth token
    put_json "/api/tutorials/#{tutorial_old.id}", data_to_put

    # Check there is no new tutorial
    assert_equal 403, last_response.status
  end

  def test_student_cannot_replace_tutorials
    # Create a dummy tutorial
    tutorial_old = FactoryBot.create(:tutorial)

    # Create dummy attributes for the tutorial
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit)
    tutor = unit.tutors.first

    tutorial = {
      unit_id: unit.id,
      tutor_id: tutor.id,
      campus_id: campus.id,
      capacity: 10,
      abbreviation: 'LA011',
      meeting_location: 'LAB34',
      meeting_day: 'Tuesday',
      meeting_time: '18:00'
    }

    data_to_put = {
      tutorial: tutorial
    }

    # The student user to perform the PUT
    student = unit.active_projects.first.student

    # Add username and auth_token to Header
    add_auth_header_for(user: student)

    # perform the put with a unit student auth token
    put_json "/api/tutorials/#{tutorial_old.id}", data_to_put

    # Check there is no new tutorial
    assert_equal 403, last_response.status
  end

  #####----------DELETE tests - Delete a tutorial----------#####

  # Testing for successful DELETEs
  def test_admin_delete_tutorial
    # Create a dummy tutorial
    tutorial = FactoryBot.create(:tutorial)
    unit = tutorial.unit

    # Ensure there are no enrolments to enable tutorial to be deleted...
    tutorial.tutorial_enrolments.each do |tutorial_enrolment|
      tutorial_enrolment.delete
    end

    # Number of tutorials before DELETE
    number_of_tutorials = Tutorial.all.length

    # Create and add an admin into the unit
    admin = FactoryBot.create(:user, :admin)
    unit.employ_staff admin, Role.admin
    admin.reload

    # Add username and auth_token to Header
    add_auth_header_for(user: admin)

    # perform the delete with an admin auth token
    delete_json "/api/tutorials/#{tutorial.id}"

    # Check that the request succeeds
    assert_equal 200, last_response.status

    # Check there is one less tutorial
    assert_equal number_of_tutorials - 1, Tutorial.all.length

    # Check that you can't find the deleted id
    refute Tutorial.exists?(tutorial.id)
  end

  def test_convenor_delete_tutorial
    # Create a dummy tutorial
    tutorial = FactoryBot.create(:tutorial)
    unit = tutorial.unit

    # Ensure there are no enrolments to enable tutorial to be deleted...
    tutorial.tutorial_enrolments.each do |tutorial_enrolment|
      tutorial_enrolment.delete
    end

    # Number of tutorials before DELETE
    number_of_tutorials = Tutorial.all.length

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    # perform the delete with an admin auth token
    delete_json "/api/tutorials/#{tutorial.id}"

    # Check that the request succeeds
    assert_equal 200, last_response.status

    # Check there is one less tutorial
    assert_equal number_of_tutorials - 1, Tutorial.all.length

    # Check that you can't find the deleted id
    refute Tutorial.exists?(tutorial.id)
  end

  # Testing for DELELTE failures
  def test_tutor_cannot_delete_tutorial
    # Create a dummy tutorial
    tutorial = FactoryBot.create(:tutorial)
    unit = tutorial.unit

    # Ensure there are no enrolments to enable tutorial to be deleted...
    tutorial.tutorial_enrolments.each do |tutorial_enrolment|
      tutorial_enrolment.delete
    end

    # Number of tutorials before DELETE
    number_of_tutorials = Tutorial.all.length

    # Create and add an admin into the unit
    tutor = FactoryBot.create(:user, :tutor)
    unit.employ_staff tutor, Role.tutor
    tutor.reload

    # Add username and auth_token to Header
    add_auth_header_for(user: tutor)

    # perform the delete with an admin auth token
    delete_json "/api/tutorials/#{tutorial.id}"

    # Check that the request succeeds
    assert_equal 403, last_response.status

    # Check there is no less tutorial
    assert_equal number_of_tutorials, Tutorial.all.length

    # Check that you can still find the deleted id
    assert Tutorial.exists?(tutorial.id)
  end

  def test_delete_tutorials_with_string_tutorial_id
    # Set a string tutorial id
    tutorial_id = 'string'

    # Number of tutorials before DELETE
    number_of_tutorials = Tutorial.all.length

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    # perform the post
    delete_json "/api/tutorials/#{tutorial_id}"

    # Check number of tutorials does not change
    assert_equal number_of_tutorials, Tutorial.all.length

    # Check on error of incorrect tutorial ID
    assert_equal 404, last_response.status
    assert last_response.body.include?('Not Found'), last_response.body
  end

  def test_delete_tutorials_with_empty_auth_token
    # Create a dummy tutorial
    tutorial = FactoryBot.create(:tutorial)

    # Number of tutorials before DELETE
    number_of_tutorials = Tutorial.all.length

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    #Override header for empty auth_token
    header 'auth_token',''

    # perform the delete with empty auth token
    delete_json "/api/tutorials/#{tutorial.id}"

    # Check authentication error
    assert_equal 419, last_response.status

    # Check number of tutorials does not change
    assert_equal number_of_tutorials , Tutorial.all.length

    # Check that you still can find the deleted id
    assert Tutorial.exists?(tutorial.id)
  end

  def test_delete_tutorials_with_incorrect_auth_token
    # Create a dummy tutorial
    tutorial = FactoryBot.create(:tutorial)

    # Add username and auth_token to Header
    add_auth_header_for(username: 'aadmin', auth_token: 'incorrect_auth_token')

     # Number of tutorials before DELETE
     number_of_tutorials = Tutorial.all.length

    # perform the delete with incorrect auth token
    delete_json "/api/tutorials/#{tutorial.id}"

    # Check authentication error
    assert_equal 419, last_response.status

    # Check number of tutorials does not change
    assert_equal number_of_tutorials , Tutorial.all.length

    # Check that you still can find the deleted id
    assert Tutorial.exists?(tutorial.id)
  end

  def test_student_cannot_delete_tutorial
    # Tutorial to delete
    tutorial = FactoryBot.create (:tutorial)

    # Number of tutorials before deletion
    number_of_tutorials = Tutorial.count

    # Student in the tutorial unit to perform the DELETE
    student = tutorial.unit.active_projects.first.student

    # Add username and auth_token to Header
    add_auth_header_for(user: student)

    # perform the delete with a unit student auth token
    delete_json "/api/tutorials/#{tutorial.id}"

    # check if the delete does not get through
    assert_equal 403, last_response.status

    # check if the number of tutorials is still the same
    assert_equal Tutorial.count, number_of_tutorials

    # Check that you still can find the deleted id
    assert Tutorial.exists?(tutorial.id)
  end

  def test_student_change_tutorial
    unit = FactoryBot.create :unit, student_count: 1, unenrolled_student_count: 0, part_enrolled_student_count: 0, tutorials: 2, inactive_student_count: 0

    project = unit.projects.first

    data_to_put = {
      id: project.id,
      submitted_grade: 2
    }

    user = project.student
    tutorial = unit.tutorials.last

    add_auth_header_for user: user

    post_json "/api/units/#{unit.id}/tutorials/#{tutorial.abbreviation}/enrolments/#{project.id}", data_to_put

    assert_equal 201, last_response.status

    assert project.enrolled_in? tutorial

    tutorial = unit.tutorials.first
    unit.allow_student_change_tutorial = false
    unit.save

    post_json "/api/units/#{unit.id}/tutorials/#{tutorial.abbreviation}/enrolments/#{project.id}", data_to_put

    assert_equal 403, last_response.status

    refute project.enrolled_in? tutorial
  end
end
