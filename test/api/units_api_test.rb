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
    data_to_post = {
      unit: {
        name: 'Intro to Social Skills',
        code: 'JRRW40003',
        start_date: '2016-05-14',
        end_date: '2017-05-14'
      }
    }
    expected_unit = data_to_post[:unit]
    unit_count = Unit.all.length

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

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
        unit: unit
    }

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first, auth_token: token)

    # Override the header for empty auth_token
    if token == ''
      header 'auth_token',''
    end

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
        unit: create_unit
    }

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

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
        unit: unit
    }

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    post_json '/api/units', data_to_post
    assert_equal count + 1, Unit.all.length

    # Changes name of unit in data_to_post automatically
    unit[:name] = 'Intro to Python'

    post_json '/api/units', data_to_post
    # Successful assertion of same length again means no record was created
    assert_equal count + 1, Unit.all.length
    assert_equal 500, last_response.status
  end

  def test_add_tutorial_to_unit
    unit = FactoryBot.create :unit, with_students: false, stream_count: 0
    count_tutorials = Tutorial.all.length

    tutorial = {
      unit_id: unit.id,
      tutor_id: unit.main_convenor_user.id,
      campus_id: Campus.first.id,
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
    add_auth_header_for(user: unit.main_convenor_user)

    # perform the post
    post_json '/api/tutorials', data_to_post
    assert_equal 201, last_response.status, last_response_body
    # Check there is a new tutorial
    assert_equal count_tutorials + 1, Tutorial.all.length, last_response_body
    assert_json_matches_model tutorial, last_response_body, ["abbreviation", "capacity", "meeting_location", "meeting_day", "meeting_time"]

    unit.destroy
  end

  # End POST tests
  # --------------------------------------------------------------------------- #

  # --------------------------------------------------------------------------- #
  # GET tests

  # Test GET for getting all units
  def test_units_get
    # Add username and auth_token to Header - aadmin
    add_auth_header_for(user: User.first)

    get '/api/units'

    actual_unit = last_response_body[0]
    expected_unit = Unit.first
    assert_equal expected_unit.name, actual_unit['name'], last_response_body
    assert_equal expected_unit.code, actual_unit['code']
    assert_equal expected_unit.start_date.to_date, actual_unit['start_date'].to_date
    assert_equal expected_unit.end_date.to_date, actual_unit['end_date'].to_date

    # Check last unit in Units (created in seed.db)
    actual_unit = last_response_body[1]
    expected_unit = Unit.find(2)

    assert_equal expected_unit.name, actual_unit['name']
    assert_equal expected_unit.code, actual_unit['code']
    assert_equal expected_unit.start_date.to_date, actual_unit['start_date'].to_date
    assert_equal expected_unit.end_date.to_date, actual_unit['end_date'].to_date
  end

  def test_permissions_on_get
    aadmin = User.find_by(username: 'aadmin')
    aauditor = FactoryBot.create :user, :auditor
    aconvenor = User.find_by(username: 'aconvenor')
    atutor = User.find_by(username: 'atutor')
    astudent = User.find_by(username: 'astudent')

    Doubtfire::Application.config.auditor_unit_start_before = Date.today

    # Test auditor can get all - except old
    test_unit = FactoryBot.create :unit, start_date: 2.years.ago, end_date: 2.years.ago + 10.weeks, with_students: false, task_count: 0
    total_units = Unit.count

    # Test admin can get all
    add_auth_header_for(user: aadmin)
    get '/api/units', { include_in_active: true }
    assert_equal 200, last_response.status
    assert_equal total_units, last_response_body.count

    add_auth_header_for(user: aauditor)
    get '/api/units', { include_in_active: true }
    assert_equal 200, last_response.status
    assert_equal total_units - 1, last_response_body.count

    # Test convenor can not get all
    add_auth_header_for(user: aconvenor)
    get '/api/units'
    assert_equal 403, last_response.status

    # Test students cannot get all
    add_auth_header_for(user: astudent)
    get '/api/units'
    assert_equal 403, last_response.status

    # Test no auth cannot get all
    clear_auth_header
    get '/api/units'
    assert_equal 419, last_response.status
  end

  # Test GET for getting a specific unit by id
  def test_units_get_by_id
    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    # Test getting the first unit with id of 1
    get '/api/units/1'

    actual_unit = last_response_body
    expected_unit = Unit.find(1)

    # Check to see if the first unit's match
    assert_equal actual_unit['name'], expected_unit.name
    assert_equal actual_unit['code'], expected_unit.code
    assert_equal actual_unit['start_date'].to_date, expected_unit.start_date.to_date
    assert_equal actual_unit['end_date'].to_date, expected_unit.end_date.to_date

    # Get response back from getting a unit by id
    # Test getting the first unit with id of 2
    get '/api/units/2'

    actual_unit = last_response_body
    expected_unit = Unit.find(2)
  end

  def test_unit_output()
    expected_unit = FactoryBot.create :unit, group_sets: 1, groups: [{ gs: 0, students: 2}], task_alignment_links: 2

    # Add username and auth_token to Header
    add_auth_header_for(user: expected_unit.main_convenor_user)

    # Get the unit...
    get "/api/units/#{expected_unit.id}"

    actual_unit = last_response_body

    # Check to see if the first unit's match
    assert_equal actual_unit['start_date'].to_date, expected_unit.start_date.to_date
    assert_equal actual_unit['end_date'].to_date, expected_unit.end_date.to_date

    keys = ["code", "id", "name", "main_convenor_id", "description", "active", "auto_apply_extension_before_deadline", "send_notifications", "enable_sync_enrolments", "enable_sync_timetable", "draft_task_definition_id", "allow_student_extension_requests", "extension_weeks_on_resubmit_request", "allow_student_change_tutorial"]

    assert actual_unit.key?("my_role"), actual_unit.inspect
    assert_equal expected_unit.role_for(expected_unit.main_convenor_user).name, actual_unit["my_role"]

    if expected_unit.teaching_period_id.nil?
      assert_nil actual_unit["teaching_period_id"], actual_unit.inspect
    else
      assert_equal expected_unit.teaching_period_id, actual_unit["teaching_period_id"], actual_unit.inspect
    end

    assert_json_matches_model expected_unit, actual_unit, keys

    assert actual_unit.key?("tutorial_streams"), actual_unit.inspect
    assert actual_unit.key?("tutorials"), actual_unit.inspect
    # assert actual_unit.key?("tutorial_enrolments"), actual_unit.inspect
    assert actual_unit.key?("task_definitions"), actual_unit.inspect
    #TODO: expand tests to check details returned

    assert actual_unit.key?("staff"), actual_unit.inspect
    assert_equal expected_unit.staff.count, actual_unit["staff"].count, actual_unit["staff"].inspect
    actual_unit["staff"].each do |staff|
      keys = %w(id role user)
      assert_json_limit_keys_to_exactly keys, staff
      ur = UnitRole.find(staff['id'])
      assert_equal ur.id, staff['id']
      assert_equal ur.role.name, staff['role']
      assert_equal ur.user.id, staff['user']['id']
      assert_equal ur.user.first_name, staff['user']['first_name']
      assert_equal ur.user.last_name, staff['user']['last_name']
      assert_equal ur.user.email, staff['user']['email']
    end

    assert actual_unit.key?("group_sets"), actual_unit.inspect
    assert_equal expected_unit.group_sets.count, actual_unit["group_sets"].count, actual_unit["group_sets"].inspect
    actual_unit["group_sets"].each do |gs|
      keys = %w(id name allow_students_to_create_groups allow_students_to_manage_groups keep_groups_in_same_class capacity locked)
      assert_json_limit_keys_to_exactly keys, gs
      assert_json_matches_model GroupSet.find(gs['id']), gs, keys
    end

    assert actual_unit.key?("ilos"), actual_unit.inspect
    assert_equal expected_unit.learning_outcomes.count, actual_unit["ilos"].count, actual_unit["ilos"].inspect
    actual_unit["ilos"].each do |outcome|
      keys = %w(id ilo_number abbreviation name description)
      assert_json_limit_keys_to_exactly keys, outcome
      assert_json_matches_model LearningOutcome.find(outcome['id']), outcome, keys
    end

    assert actual_unit.key?("task_outcome_alignments"), actual_unit.inspect
    assert_equal expected_unit.task_outcome_alignments.count, actual_unit["task_outcome_alignments"].count, actual_unit["task_outcome_alignments"].inspect
    actual_unit["task_outcome_alignments"].each do |align|
      keys = %w(id description rating learning_outcome_id task_definition_id)
      assert_json_limit_keys_to_exactly keys, align
      assert_json_matches_model LearningOutcomeTaskLink.find(align['id']), align, keys
    end

    assert actual_unit.key?("groups"), actual_unit.inspect
    assert_equal expected_unit.groups.count, actual_unit["groups"].count, actual_unit["groups"].inspect
    actual_unit["groups"].each do |group|
      keys = %w(id name tutorial_id group_set_id student_count capacity_adjustment locked)
      assert_json_limit_keys_to_exactly keys, group
      assert_json_matches_model Group.find(group['id']), group, keys
    end
  end

  def test_units_get_has_streams
    expected_unit = FactoryBot.create(:unit, with_students: false, stream_count: 2)

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    # Get the unit...
    get "/api/units/#{expected_unit.id}"

    actual_unit = last_response_body

    # Check to see if the first unit's match
    assert_equal actual_unit['name'], expected_unit.name
    assert_equal actual_unit['code'], expected_unit.code
    assert_equal actual_unit['start_date'].to_date, expected_unit.start_date.to_date
    assert_equal actual_unit['end_date'].to_date, expected_unit.end_date.to_date

    assert_equal 2, actual_unit['tutorial_streams'].count, actual_unit.inspect

    expected_unit = FactoryBot.create(:unit, with_students: false, stream_count: 3)

    # Get the unit...
    get "/api/units/#{expected_unit.id}"

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

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    get '/api/units'
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
      unit:unit
    }

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    put_json '/api/units/1', data_to_put
    assert_equal 200, last_response.status

    assert_json_matches_model Unit.first, unit, %w( name code description start_date end_date active auto_apply_extension_before_deadline send_notifications )
  end

  #Test PUT for updating unit details with empty name
  def test_put_update_unit_empty_name
    unit = Unit.first
    unit[:name] = ''

    data_to_put = {
        unit: unit
    }

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    put_json '/api/units/1', data_to_put
    assert_equal 400, last_response.status
  end

  #Test PUT for updating unit details with invalid id
  def test_put_update_unit_invalid_id
    data_to_put = {
        unit: { name: 'test'}
    }

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    put_json '/api/units/12', data_to_put
    assert_equal 404, last_response.status
  end

  # Test can update unit start and end dates
  def test_put_update_unit_dates
    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    new_start = Unit.first.start_date - 1.week
    new_end = Unit.first.end_date - 1.week

    put_json '/api/units/1', { unit: { start_date: new_start } }
    assert_equal 200, last_response.status, last_response_body

    assert_equal new_start.to_i, Unit.first.start_date.to_i

    put_json '/api/units/1', { unit: { end_date: new_end } }
    assert_equal 200, last_response.status

    assert_equal new_end.to_i, Unit.first.end_date.to_i
  end

  # Test GET for getting a specific unit by invalid id
  def test_fail_units_get_by_id
    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    get '/api/units/12'
    assert_equal 404, last_response.status
  end

  def test_put_update_unit_custom_token()
    unit = Unit.first
    token = 'abcdef'
    data_to_put = {
      unit: unit
    }

    # Add username and auth_token to Header
    add_auth_header_for(auth_token: token, username: 'aadmin')

    put_json '/api/units/1', data_to_put
    assert_equal 419, last_response.status
  end

  def test_put_update_unit_empty_token
    unit = Unit.first
    data_to_put = {
      unit: unit
    }

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    # Override header for empty string
    header 'auth_token', ''

    put_json '/api/units/1', data_to_put
    assert_equal 419, last_response.status
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

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    put_json "/api/units/#{unit.id}", data_to_put

    unit.reload
    assert_equal 200, last_response.status
    assert_equal convenor_user_role.id, unit.main_convenor_id
  end

  def test_draft_learning_summary_upload_requirements
    unit = FactoryBot.create :unit, student_count: 1, task_count: 0
    task_def_code = FactoryBot.create(:task_definition, unit: unit, upload_requirements: [{'key' => 'file0','name' => 'Code file','type' => 'code'}])
    task_def_doc = FactoryBot.create(:task_definition, unit: unit, upload_requirements: [{'key' => 'file0','name' => 'Draft learning summary','type' => 'document'}])
    task_def_doc_code = FactoryBot.create(:task_definition, unit: unit, upload_requirements: [{'key' => 'file0','name' => 'Draft learning summary','type' => 'document'}, {'key' => 'file1','name' => 'Code file','type' => 'code'}])

    # Test with a task containing non document upload requirement
    data_to_put = {
      unit: {
        draft_task_definition_id: task_def_code.id
      }
    }

    add_auth_header_for user: unit.main_convenor_user
    put_json "/api/units/#{unit.id}", data_to_put

    assert_equal 403, last_response.status
    unit.reload
    assert_nil unit.draft_task_definition_id

    # Test with task containing multiple upload requirements
    data_to_put = {
      unit: {
        draft_task_definition_id: task_def_doc_code.id
      }
    }

    add_auth_header_for user: unit.main_convenor_user
    put_json "/api/units/#{unit.id}", data_to_put

    assert_equal 403, last_response.status
    unit.reload
    assert_nil unit.draft_task_definition_id

    # Test with a singular document upload (valid draft learning summary task definition)
    data_to_put = {
      unit: {
        draft_task_definition_id: task_def_doc.id
      }
    }

    add_auth_header_for user: unit.main_convenor_user
    put_json "/api/units/#{unit.id}", data_to_put

    assert_equal 200, last_response.status
    unit.reload
    assert_equal task_def_doc.id, unit.draft_task_definition_id
  end
end
