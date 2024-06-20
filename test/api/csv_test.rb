require 'test_helper'

class CsvTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::TestFileHelper

  def app
    Rails.application
  end

  # --------------------------------------------------------------------------- #
  # --- Endpoint testing for:
  # ------- /api/csv
  # ------- GET POST

  # --------------------------------------------------------------------------- #

  #####--------------GET tests - Download CSV of all task definitions for the given unit------------######

  #1: Testing for CSV download of all the task definitions for a given unit
  #GET /api/csv/task_definitions
  def test_download_csv_all_task_definitions_unit

    unit_id_to_test = '1'


    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    # perform the get
    get "/api/csv/task_definitions?unit_id=#{unit_id_to_test}"

    # Check for response
    assert_equal 200, last_response.status

    # Check for file
    assert_equal "attachment; filename=COS10001-Tasks.csv",last_response.headers["content-disposition"]
  end

  #2: Testing for unit ID error with empty user ID
  #GET /api/csv/task_definitions
  def test_download_csv_all_task_definitions_unit_with_empty_unit_id

    unit_id_to_test = ''

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    # perform the get
    get "/api/csv/task_definitions?unit_id=#{unit_id_to_test}"

    # Check for response
    assert_equal 404, last_response.status
  end

  #3: Testing for unit ID error with incorrect user ID
  #GET /api/csv/task_definitions
  def test_download_csv_all_task_definitions_unit_with_incorrect_unit_id

    unit_id_to_test = '999'

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    # perform the get
    get "/api/csv/task_definitions?unit_id=#{unit_id_to_test}"

    # Check for response
    assert_equal 404, last_response.status
  end

  #4: Testing for unit ID error with string user ID
  #GET /api/csv/task_definitions
  def test_download_csv_all_task_definitions_unit_with_string_unit_id

    unit_id_to_test = 'string'

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    # perform the get
    get "/api/csv/task_definitions?unit_id=#{unit_id_to_test}"

    # Check for response
    assert_equal 400, last_response.status
  end

  #5: Testing for authentication failure with incorrect token
  #GET /api/csv/task_definitions
  def test_download_csv_all_task_definitions_unit_with_incorrect_auth_token

    unit_id_to_test = 'string'

    # auth_token and username added to header
    add_auth_header_for(auth_token: "wrong token", username: 'aadmin')

    # perform the get
    get "/api/csv/task_definitions?unit_id=#{unit_id_to_test}"

    # Check for response
    assert_equal 419, last_response.status
  end

  #6: Testing for authentication failure with empty token
  #GET /api/csv/task_definitions
  def test_download_csv_all_task_definitions_unit_with_empty_auth_token

    unit_id_to_test = 'string'

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    # Overwrite header for empty auth_token
    header 'auth_token',''

    # perform the get
    get "/api/csv/task_definitions?unit_id=#{unit_id_to_test}"

    # Check for response
    assert_equal 419, last_response.status
  end

  #####--------------POST tests - Upload CSV of task definitions to the provided unit------------######

  #7: Testing for CSV upload all task definitions for the given unit
  #POST /api/csv/task_definitions
  def test_csv_upload_all_task_definitions_unit

    data_to_post = {
      unit_id: '1',
      file: upload_file_csv('test_files/csv_test_files/COS10001-Tasks.csv')
    }

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    # perform the POST
    post "/api/csv/task_definitions", data_to_post

    assert_equal 201, last_response.status
    assert_equal 'Assignment 12', TaskDefinition.where(abbreviation: 'A12').first.name
  end

  #8: Testing for CSV upload failure due to incorrect auth token
  #POST /api/csv/task_definitions
  def test_csv_upload_all_task_definitions_unit_incorrect_auth_token

    data_to_post = {
      unit_id: '1',
      file: upload_file_csv('test_files/csv_test_files/COS10001-Tasks.csv')
    }

    # auth_token and username added to header
    add_auth_header_for(username: 'aadmin', auth_token: "wrong_token")

    # perform the POST
    post "/api/csv/task_definitions", data_to_post

    assert_equal 419, last_response.status
  end

  #9: Testing for CSV upload failure due to empty auth token
  #POST /api/csv/task_definitions
  def test_csv_upload_all_task_definitions_unit_empty_auth_token

    data_to_post = {
      unit_id: '1',
      file: upload_file_csv('test_files/csv_test_files/COS10001-Tasks.csv')
    }

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    # Overwrite header for empty auth_token
    header 'auth_token',''

    # perform the POST
    post "/api/csv/task_definitions", data_to_post

    assert_equal 419, last_response.status
  end

  #10: Testing for CSV upload failure due to string unit ID
  #POST /api/csv/task_definitions
  def test_csv_upload_all_task_definitions_unit_string_unit_id

    data_to_post = {
      unit_id: 'string',
      file: upload_file_csv('test_files/csv_test_files/COS10001-Tasks.csv')
    }

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    # perform the POST
    post "/api/csv/task_definitions", data_to_post

    assert_equal 400, last_response.status
  end

  #11: Testing for CSV upload failure due to empty unit ID
  #POST /api/csv/task_definitions
  def test_csv_upload_all_task_definitions_unit_empty_unit_id

    data_to_post = {
      unit_id: '',
      file: upload_file_csv('test_files/csv_test_files/COS10001-Tasks.csv')
    }

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    # perform the POST
    post "/api/csv/task_definitions", data_to_post

    assert_equal 404, last_response.status
  end

  #12: Testing for CSV upload of xlsx file type
  #POST /api/csv/task_definitions
  def test_csv_upload_all_task_definitions_unit_xlsx

    unit = FactoryBot.create(:unit, with_students: false)

    data_to_post = {
      unit_id: unit.id,
      file: upload_file_csv('test_files/csv_test_files/COS10001-Tasks.xlsx')
    }

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    tdc = unit.task_definitions.count

    # perform the POST
    post "/api/csv/task_definitions", data_to_post

    unit.reload

    assert_equal 201, last_response.status
    assert_equal 1, last_response_body['success'].count, last_response.body
    assert_equal tdc + 1, unit.task_definitions.count
  end

  #13: Testing for CSV upload failure due to incorrect file type (PDF)
  #POST /api/csv/task_definitions
  def test_csv_upload_all_task_definitions_unit_incorrect_file_pdf

    data_to_post = {
      unit_id: '1',
      file: upload_file_csv('test_files/csv_test_files/COS10001-Tasks.pdf')
    }

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    # perform the POST
    post "/api/csv/task_definitions", data_to_post

    assert_equal 403, last_response.status
  end

  #14: Testing for CSV upload failure due to no file
  #POST /api/csv/task_definitions
  def test_csv_upload_all_task_definitions_unit_no_file

    data_to_post = {
      unit_id: '1',
      file: '',
    }

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    # perform the POST
    post "/api/csv/task_definitions", data_to_post

    assert_equal 400, last_response.status
  end

  #15: Testing for CSV upload failure due to non-existant unit id
  #POST /api/csv/task_definitions
  def test_csv_upload_all_task_definitions_unit_incorrect_unit_id

    data_to_post = {
      unit_id: '9999',
      file: upload_file_csv('test_files/csv_test_files/COS10001-Tasks.csv')
    }

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    # perform the POST
    post "/api/csv/task_definitions", data_to_post

    assert_equal 404, last_response.status
  end

  #####--------------GET tests - Download CSV of all students in this unit------------######

  #16: Testing for CSV download of all the students in a unit
  #GET /api/csv/units/{id}
  def test_download_csv_all_students_in_unit

    unit_id_to_test = '1'

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    # perform the get
    get "/api/csv/units/#{unit_id_to_test}"

    # Check for response
    assert_equal 200, last_response.status

    # Check for file
    assert_equal "attachment; filename=COS10001-Students.csv",last_response.headers["content-disposition"]
  end

  #18: Testing for unit ID error with string unit ID
  #GET /api/csv/units/{id}
  def test_download_csv_all_students_in_unit_with_string_unit_id

    unit_id_to_test = 'string'

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    # perform the get
    get "/api/csv/units/#{unit_id_to_test}"

    # Check for response
    assert_equal 404, last_response.status
  end

  #19: Testing for unit ID error with incorrect (non-existant) user ID
  #GET /api/csv/units/{id}
  def test_download_csv_all_students_in_unit_with_incorrect_unit_id

    unit_id_to_test = '999'

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    # perform the get
    get "/api/csv/units/#{unit_id_to_test}"

    # Check for response
    assert_equal 404, last_response.status
  end

  #20: Testing for authentication failure with incorrect token
  #GET /api/csv/units/{id}
  def test_download_csv_all_students_in_unit_with_incorrect_auth_token

    unit_id_to_test = '1'

    # auth_token and username added to header
    add_auth_header_for(username: 'aadmin', auth_token: 'wrong_token')

    # perform the get
    get "/api/csv/units/#{unit_id_to_test}"

    # Check for response
    assert_equal 419, last_response.status
  end

  #21: Testing for authentication failure with empty token
  #GET /api/csv/units/{id}
  def test_download_csv_all_students_in_unit_with_empty_auth_token

    unit_id_to_test = '1'

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    #Override header for empty auth_token
    header 'auth_token',''

    # perform the get
    get "/api/csv/units/#{unit_id_to_test}"

    # Check for response
    assert_equal 419, last_response.status
  end

  #####--------------POST tests - Upload CSV of all the students in a unit------------######

  #22: Testing for CSV upload of all the students in a unit
  #POST /api/csv/units/{id}
  def test_csv_upload_all_students_in_unit
    unit = FactoryBot.create(:unit, code: 'COS10001', with_students: false, stream_count: 0)

    data_to_post = {
      file: upload_file_csv('test_files/csv_test_files/COS10001-Students.csv')
    }

    # auth_token and username added to header
    add_auth_header_for(auth_token: auth_token(unit.main_convenor_user), username: unit.main_convenor_user.username)

    # perform the POST
    post "/api/csv/units/#{unit.id}", data_to_post

    user_id_check = unit.projects.last.user_id

    # Check for response
    assert_equal 201, last_response.status
    assert_equal 'test_csv_student', User.where(id: user_id_check).last.username, last_response_body

    unit.destroy
  end

  #23: Testing for CSV upload failure due to incorrect auth token
  #POST /api/csv/units/{id}
  def test_csv_upload_all_students_in_unit_incorrect_auth_token
    unit = FactoryBot.create(:unit, code: 'COS10001', with_students: false, stream_count: 0)

    data_to_post = {
      file: upload_file_csv('test_files/csv_test_files/COS10001-Students.csv')
    }

    # auth_token and username added to header
    add_auth_header_for(username: 'aadmin', auth_token: "wrong_token")

    # perform the POST
    post "/api/csv/units/#{unit.id}", data_to_post

    assert_equal 419, last_response.status
  end

  #24: Testing for CSV upload failure due to empty auth token
  #POST /api/csv/units/{id}
  def test_csv_upload_all_students_in_unit_empty_auth_token
    unit = FactoryBot.create(:unit, code: 'COS10001', with_students: false, stream_count: 0)
    data_to_post = {
      file: upload_file_csv('test_files/csv_test_files/COS10001-Students.csv'),
      auth_token: ''
    }

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    # Override the header for empty auth_token
    header 'auth_token',''

    # perform the POST
    post "/api/csv/units/#{unit.id}", data_to_post

    assert_equal 419, last_response.status
  end

  #25: Testing for CSV upload failure due to string unit ID
  #POST /api/csv/units/{id}
  def test_csv_upload_all_students_in_unit_string_unit_id
    data_to_post = {
      file: upload_file_csv('test_files/csv_test_files/COS10001-Students.csv')
    }

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    # perform the POST
    post "/api/csv/units/test", data_to_post

    assert_equal 404, last_response.status
  end

  #28: Testing for CSV upload failure due to incorrect file type (PDF)
  #POST /api/csv/units/{id}
  def test_csv_upload_all_students_in_unit_incorrect_file_pdf
    unit = FactoryBot.create(:unit, code: 'COS10001', with_students: false, stream_count: 0)

    data_to_post = {
      file: upload_file_csv('test_files/csv_test_files/COS10001-Students.pdf')
    }

    # auth_token and username added to header
    add_auth_header_for(user: unit.main_convenor_user)

    # perform the POST
    post "/api/csv/units/#{unit.id}", data_to_post

    assert_equal 403, last_response.status
  end

  #29: Testing for CSV upload failure due to no file
  #POST /api/csv/units/{id}
  def test_csv_upload_all_students_in_unit_no_file
    unit = FactoryBot.create(:unit, code: 'COS10001', with_students: false, stream_count: 0)

    data_to_post = {
      file: ''
    }

    # auth_token and username added to header
    add_auth_header_for(auth_token: auth_token(unit.main_convenor_user), username: unit.main_convenor_user.username)

    # perform the POST
    post "/api/csv/units/#{unit.id}", data_to_post

    assert_equal 400, last_response.status
  end

  #30: Testing for CSV upload failure due to non-existant unit id
  #POST /api/csv/units/{id}
  def test_csv_upload_all_students_in_unit_incorrect_unit_id

    unit_id_to_test = '999'
    data_to_post = {
      file: upload_file_csv('test_files/csv_test_files/COS10001-Students.csv')
    }

    # auth_token and username added to header
    add_auth_header_for(user: User.first)
    # perform the POST
    post "/api/csv/units/#{unit_id_to_test}", data_to_post

    assert_equal 404, last_response.status
  end

  #####--------------POST tests - Upload CSV with the students to un-enrol from the unit------------######

  #31: Testing for CSV upload of all the students in a unit
  #POST /api/csv/units/{id}/withdraw
  def test_csv_upload_students_un_enroll_in_unit
    unit = FactoryBot.create(:unit, code: 'COS10001', with_students: false, stream_count: 0)

    # Adding user to withdraw from unit
    unit.import_users_from_csv test_file_path 'csv_test_files/COS10001-Students.csv'

    data_to_post = {
      file: upload_file_csv('test_files/csv_test_files/COS10001-Students.csv')
    }

    # auth_token and username added to header
    add_auth_header_for(auth_token: auth_token(unit.main_convenor_user), username: unit.main_convenor_user.username)

    user_id_check = unit.projects.last.user_id

    # perform the POST to withdraw user from the unit
    post "/api/csv/units/#{unit.id}/withdraw", data_to_post

    # Check for response
    assert_equal 201, last_response.status
    assert_equal 'test_csv_student', User.where(id: user_id_check).last.username
    assert_equal false, Project.where(user_id: user_id_check).last.enrolled
  end

  #32: Testing for CSV upload failure due to incorrect auth token
  #POST /api/csv/units/{id}/withdraw
  def test_csv_upload_students_un_enroll_in_unit_incorrect_auth_token
    unit = FactoryBot.create(:unit, code: 'COS10001', with_students: false, stream_count: 0)

    # Adding user to withdraw from unit
    unit.import_users_from_csv test_file_path 'csv_test_files/COS10001-Students.csv'

    data_to_post = {
      file: upload_file_csv('test_files/csv_test_files/COS10001-Students.csv')
    }

    # auth_token and username added to header
    add_auth_header_for(username: 'aadmin', auth_token: "wrong_token")

    # perform the POST to withdraw user from the unit
    post "/api/csv/units/#{unit.id}/withdraw", data_to_post

    user_id_check = unit.projects.last.user_id

    # Check for response
    assert_equal 419, last_response.status
    # Check student was not withdrawn
    assert_equal 'test_csv_student', User.where(id: user_id_check).last.username
    assert_equal true, unit.projects.last.enrolled
  end

  #33: Testing for CSV upload failure due to empty auth token
  #POST /api/csv/units/{id}/withdraw
  def test_csv_upload_students_un_enroll_in_unit_empty_auth_token

    unit = FactoryBot.create(:unit, code: 'COS10001', with_students: false, stream_count: 0)
    response = unit.import_users_from_csv test_file_path 'csv_test_files/COS10001-Students.csv'
    assert_equal 1, unit.projects.count, response


    unit_id_to_test = '1'
    data_to_post = {
      file: upload_file_csv('test_files/csv_test_files/COS10001-Students.csv')
    }

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    #Override header for empty auth_token
    header 'auth_token',''

    user_id_check = unit.projects.last.user_id

    # perform the POST to withdraw user from the unit
    post "/api/csv/units/#{unit_id_to_test}/withdraw", data_to_post

    # Check for response
    assert_equal 419, last_response.status
    # Check student was not withdrawn
    assert_equal 'test_csv_student', User.where(id: user_id_check).last.username
    assert_equal true, unit.projects.last.enrolled
  end

  #34: Testing for CSV upload failure due to string unit ID
  #POST /api/csv/units/{id}/withdraw
  def test_csv_upload_students_un_enroll_in_unit_string_unit_id

    # Adding user to withdraw from unit
    unit = FactoryBot.create(:unit, code: 'COS10001', with_students: false, stream_count: 0)
    unit.import_users_from_csv test_file_path 'csv_test_files/COS10001-Students.csv'

    user_id_check = unit.projects.last.user_id

    data_to_post = {
      file: upload_file_csv('test_files/csv_test_files/COS10001-Students.csv')
    }

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    # perform the POST to withdraw user from the unit
    post "/api/csv/units/test/withdraw", data_to_post

    # Check for response
    assert_equal 404, last_response.status
    # Check student was not withdrawn
    assert_equal 'test_csv_student', User.where(id: user_id_check).last.username
    assert_equal true, Project.where(user_id: user_id_check).last.enrolled

    unit.destroy
  end

  #35: Testing for CSV upload failure due to empty unit ID
  #POST /api/csv/units/{id}/withdraw
  def test_csv_upload_students_un_enroll_in_unit_empty_unit_id

    unit = FactoryBot.create(:unit, code: 'COS10001', with_students: false, stream_count: 0)
    unit.import_users_from_csv test_file_path 'csv_test_files/COS10001-Students.csv'

    unit_id_to_test = ''
    data_to_post = {
      file: upload_file_csv('test_files/csv_test_files/COS10001-Students.csv')
    }

    # auth_token and username added to header
    add_auth_header_for(user: unit.main_convenor_user)

    user_id_check = unit.projects.last.user_id

    # perform the POST to withdraw user from the unit
    post "/api/csv/units/#{unit_id_to_test}/withdraw", data_to_post

    # Check for response
    assert_equal 404, last_response.status
    # Check student was not withdrawn
    assert_equal 'test_csv_student', User.where(id: user_id_check).last.username
    assert_equal true, Project.where(user_id: user_id_check).last.enrolled
  end

  #36: Testing for CSV uploadof XLSX
  #POST /api/csv/units/{id}/withdraw
  def test_csv_upload_students_un_enroll_in_unit_xlsx

    unit = FactoryBot.create(:unit, code: 'COS10001', with_students: false, stream_count: 0)

    unit.import_users_from_csv test_file_path 'csv_test_files/COS10001-Students.csv'

    unit_id_to_test = unit.id
    data_to_post = {
      file: upload_file_csv('test_files/csv_test_files/COS10001-Students.xlsx')
    }

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    user_id_check = unit.projects.last.user_id

    # perform the POST to withdraw user from the unit
    post "/api/csv/units/#{unit_id_to_test}/withdraw", data_to_post

    # Check for response
    assert_equal 201, last_response.status
    # Check success
    assert_equal 1, last_response_body['success'].count, last_response_body
  end

  #37: Testing for CSV upload failure due to incorrect file type (PDF)
  #POST /api/csv/units/{id}/withdraw
  def test_csv_upload_students_un_enroll_in_unit_incorrect_file_pdf

    unit = FactoryBot.create(:unit, code: 'COS10001', with_students: false, stream_count: 0)
    unit.import_users_from_csv test_file_path 'csv_test_files/COS10001-Students.csv'


    unit_id_to_test = unit.id
    data_to_post = {
      file: upload_file_csv('test_files/csv_test_files/COS10001-Students.pdf')
    }

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    user_id_check = unit.projects.last.user_id

    # perform the POST to withdraw user from the unit
    post "/api/csv/units/#{unit_id_to_test}/withdraw", data_to_post

    # Check for response
    assert_equal 403, last_response.status
    # Check student was not withdrawn
    assert_equal 'test_csv_student', User.where(id: user_id_check).last.username
    assert_equal true, Project.where(user_id: user_id_check).last.enrolled
  end

  # 38: Testing for CSV upload failure due to no file
  # POST /api/csv/units/{id}/withdraw
  def test_csv_upload_students_un_enroll_in_unit_no_file

    unit = FactoryBot.create(:unit, code: 'COS10001', with_students: false, stream_count: 0)
    unit.import_users_from_csv test_file_path 'csv_test_files/COS10001-Students.csv'

    unit_id_to_test = '1'
    data_to_post = {
      file: ''
    }

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    user_id_check = unit.projects.last.user_id

    # perform the POST to withdraw user from the unit
    post "/api/csv/units/#{unit_id_to_test}/withdraw", data_to_post

    # Check for response
    assert_equal 400, last_response.status
    # Check student was not withdrawn
    assert_equal 'test_csv_student', User.where(id: user_id_check).last.username
    assert_equal true, Project.where(user_id: user_id_check).last.enrolled
  end

  #39: Testing for CSV upload failure due to non-existant unit id
  #POST /api/csv/units/{id}/withdraw
  def test_csv_upload_students_un_enroll_in_unit_incorrect_unit_id

    unit = FactoryBot.create(:unit, code: 'COS10001', with_students: false, stream_count: 0)
    unit.import_users_from_csv test_file_path 'csv_test_files/COS10001-Students.csv'

   # auth_token and username added to header
    add_auth_header_for(user: User.first)

    unit_id_to_test = '999'
    data_to_post = {
      file: upload_file_csv('test_files/csv_test_files/COS10001-Students.csv')
    }

    user_id_check = unit.projects.last.user_id

    # perform the POST to withdraw user from the unit
    post "/api/csv/units/#{unit_id_to_test}/withdraw", data_to_post

    # Check for response
    assert_equal 404, last_response.status
    # Check student was not withdrawn
    assert_equal 'test_csv_student', User.where(id: user_id_check).last.username
    assert_equal true, Project.where(user_id: user_id_check).last.enrolled
  end

  #####--------------GET tests - Download CSV of all student tasks in this unit------------######

  #40: Testing for CSV download of all  students tasks in a unit
  #GET /api/csv/units/{id}/task_completion
  def test_download_csv_all_student_tasks_in_unit

    unit_id_to_test = '1'

   # auth_token and username added to header
    add_auth_header_for(user: User.first)

    # perform the get
    get "/api/csv/units/#{unit_id_to_test}/task_completion"

    # Check for response
    assert_equal 200, last_response.status

    # Check for file
    assert_equal "attachment; filename=COS10001-TaskCompletion.csv",last_response.headers["content-disposition"]
  end

  #41: Testing for unit ID error with empty user ID
  #GET /api/csv/units/{id}/task_completion
  def test_download_csv_all_student_tasks_in_unit_with_empty_unit_id

    unit_id_to_test = ''

   # auth_token and username added to header
    add_auth_header_for(user: User.first)

    # perform the get
    get "/api/csv/units/#{unit_id_to_test}/task_completion"

    # Check for response
    assert_equal 404, last_response.status
  end

  #42: Testing for unit ID error with string user ID
  #GET /api/csv/units/{id}/task_completion
  def test_download_csv_all_student_tasks_in_unit_with_string_unit_id

    unit_id_to_test = 'string'

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    # perform the get
    get "/api/csv/units/#{unit_id_to_test}/task_completion"

    # Check for response
    assert_equal 404, last_response.status
  end

  #43: Testing for unit ID error with incorrect (non-existant) user ID
  #GET /api/csv/units/{id}/task_completion
  def test_download_csv_all_student_tasks_in_unit_with_incorrect_unit_id

    unit_id_to_test = '999'

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    # perform the get
    get "/api/csv/units/#{unit_id_to_test}/task_completion"

    # Check for response
    assert_equal 404, last_response.status
  end

  #44: Testing for authentication failure with incorrect token
  #GET /api/csv/units/{id}/task_completion
  def test_download_csv_all_student_tasks_in_unit_with_incorrect_auth_token

    unit_id_to_test = '1'

    # Add authentication token to header
    add_auth_header_for(auth_token: 'wrong_token')

    # perform the get
    get "/api/csv/units/#{unit_id_to_test}/task_completion"

    # Check for response
    assert_equal 419, last_response.status
  end

  #45: Testing for authentication failure with empty token
  #GET /api/csv/units/{id}/task_completion
  def test_download_csv_all_student_tasks_in_unit_with_empty_auth_token

    unit_id_to_test = '1'

    # Add authentication token to header
    add_auth_header_for(user: User.first)

    # Override header for empty auth_token
    header 'auth_token', ''

    # perform the get
    get "/api/csv/units/#{unit_id_to_test}/task_completion"

    # Check for response
    assert_equal 419, last_response.status
  end

  # #####--------------GET tests - Download stats related to the number of tasks assessed by each tutor------------######

  # 46: Testing for CSV download of stats related to number of tasks assessed by each tutor
  # GET /api/csv/units/{id}/tutor_assessments
  def test_download_csv_stats_tutor_assessed
    unit_id_to_test = '1'

    # Add authentication token to header
    add_auth_header_for(user: User.first)

    # perform the get
    get "/api/csv/units/#{unit_id_to_test}/tutor_assessments"

    # Check for response
    assert_equal 200, last_response.status

    # Check for file
    assert_equal "attachment; filename=COS10001-TutorAssessments.csv",last_response.headers["content-disposition"]
  end

  #47: Testing for unit ID error with empty user ID
  #GET /api/csv/units/{id}/tutor_assessments
  def test_download_csv_stats_tutor_assessed_with_empty_unit_id

    unit_id_to_test = ''

    # Add authentication token to header
    add_auth_header_for(user: User.first)

    # perform the get
    get "/api/csv/units/#{unit_id_to_test}/tutor_assessments"

    # Check for response
    assert_equal 404, last_response.status
  end

  #48: Testing for unit ID error with string user ID
  #GET /api/csv/units/{id}/tutor_assessments
  def test_download_csv_stats_tutor_assessed_with_string_unit_id

    unit_id_to_test = 'string'

    # Add authentication token to header
    add_auth_header_for(user: User.first)
    # perform the get
    get "/api/csv/units/#{unit_id_to_test}/tutor_assessments"

    # Check for response
    assert_equal 404, last_response.status
  end

  #49: Testing for unit ID error with incorrect (non-existant) user ID
  #GET /api/csv/units/{id}/tutor_assessments
  def test_download_csv_stats_tutor_assessed_with_incorrect_unit_id

    unit_id_to_test = '999'

    # Add authentication token to header
    add_auth_header_for(user: User.first)

    # perform the get
    get "/api/csv/units/#{unit_id_to_test}/tutor_assessments"

    # Check for response
    assert_equal 404, last_response.status
  end

  #50: Testing for authentication failure with incorrect token
  #GET /api/csv/units/{id}/tutor_assessments
  def test_download_csv_stats_tutor_assessed_with_incorrect_auth_token

    unit_id_to_test = '1'

    # Add authentication token to header
    add_auth_header_for(username: 'aadmin', auth_token: 'wrong_token')

    # perform the get
    get "/api/csv/units/#{unit_id_to_test}/tutor_assessments"

    # Check for response
    assert_equal 419, last_response.status
  end

  #51: Testing for authentication failure with empty token
  #GET /api/csv/units/{id}/tutor_assessments
  def test_download_csv_stats_tutor_assessed_with_empty_auth_token

    unit_id_to_test = '1'

    # Add authentication token to header
    add_auth_header_for(user: User.first)

    #Override header for empty auth_token
    header 'auth_token',''

    # perform the get
    get "/api/csv/units/#{unit_id_to_test}/tutor_assessments"

    # Check for response
    assert_equal 419, last_response.status
  end

  #####--------------GET tests - Download CSV of all users------------######

  #52: Testing for CSV download of stats related to number of tasks assessed by each tutor
  #GET /api/csv/users
  def test_download_csv_all_users

    # Add authentication token to header
    add_auth_header_for(user: User.first)

    # perform the get
    get "/api/csv/users"

    # Check for response
    assert_equal 200, last_response.status

    # Check for file
    assert_equal "attachment; filename=doubtfire_users.csv",last_response.headers["content-disposition"]
  end

  #53: Testing for authentication failure with incorrect token
  #GET /api/csv/users
  def test_download_csv_all_users_with_incorrect_auth_token

    # Add authentication token to header
    add_auth_header_for(username: 'aadmin', auth_token: 'wrong_token')

    # perform the get
    get "/api/csv/users"

    # Check for response
    assert_equal 419, last_response.status
  end

  #54: Testing for authentication failure with empty token
  #GET /api/csv/users
  def test_download_csv_all_users_with_empty_auth_token

    # Add authentication token to header
    add_auth_header_for(user: User.first)

    #Override header for empty auth_token
    header 'auth_token',''

    # perform the get
    get "/api/csv/users"

    # Check for response
    assert_equal 419, last_response.status
  end

  #####--------------POST tests - Upload CSV of users------------######

  #55: Testing for CSV upload of users
  #POST /api/csv/users
  def test_csv_upload_users

    data_to_post = {
      file: upload_file_csv('test_files/csv_test_files/doubtfire_users.csv')
    }

    # Add authentication token to header
    add_auth_header_for(user: User.first)

    # perform the POST to withdraw user from the unit
    post "/api/csv/users", data_to_post

    # Check for response
    assert_equal 201, last_response.status
    assert_equal 'test.case@doubtfire.com', User.last.email
  end

  #56: Testing for CSV upload failure due to incorrect auth token
  #POST /api/csv/units/{id}/withdraw
  def test_csv_upload_users_incorrect_auth_token

    data_to_post = {
      file: upload_file_csv('test_files/csv_test_files/doubtfire_users.csv')
    }

    # Add authentication token to header
    add_auth_header_for(username: 'aadmin', auth_token: 'wrong_token')

    # perform the POST to withdraw user from the unit
    post "/api/csv/users", data_to_post

    # Check for response
    assert_equal 419, last_response.status
  end

  #57: Testing for CSV upload failure due to empty auth token
  #POST /api/csv/units/{id}/withdraw
  def test_csv_upload_users_empty_auth_token

    data_to_post = {
      file: upload_file_csv('test_files/csv_test_files/doubtfire_users.csv'),
    }

    # Add authentication token to header
    add_auth_header_for(user: User.first)

    #Override header for empty auth_token
    header 'auth_token',''

    # perform the POST to withdraw user from the unit
    post "/api/csv/users", data_to_post

    # Check for response
    assert_equal 419, last_response.status
  end

  #58: Testing for CSV upload of XLSX
  #POST /api/csv/units/{id}/withdraw
  def test_csv_upload_users_xlsx

    data_to_post = {
      file: upload_file_csv('test_files/csv_test_files/doubtfire_users.xlsx')
  }

    # Add authentication token to header
    add_auth_header_for(user: User.first)
    # perform the POST to withdraw user from the unit
    post "/api/csv/users", data_to_post

    # Check for response
    assert_equal 201, last_response.status
    assert_equal 1, last_response_body['ignored'].count, last_response_body
  end

  #59: Testing for CSV upload failure due to incorrect file type (PDF)
  #POST /api/csv/units/{id}/withdraw
  def test_csv_upload_users_incorrect_file_pdf

    data_to_post = {
      file: upload_file_csv('test_files/csv_test_files/doubtfire_users.pdf')
    }

    # Add authentication token to header
    add_auth_header_for(user: User.first)

    # perform the POST to withdraw user from the unit
    post "/api/csv/users", data_to_post

    # Check for response
    assert_equal 403, last_response.status
  end

  #60: Testing for CSV upload failure due to no file
  #POST /api/csv/units/{id}/withdraw
  def test_csv_upload_users_no_file

    data_to_post = {
      file: ''
    }

    # Add authentication token to header
    add_auth_header_for(user: User.first)

    # perform the POST to withdraw user from the unit
    post "/api/csv/users", data_to_post

    # Check for response
    assert_equal 400, last_response.status
  end
end
