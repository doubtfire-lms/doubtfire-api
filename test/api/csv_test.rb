require 'test_helper'

class CsvTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::TestFileHelper

  def app
    Rails.application
  end

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

  # 7: Testing for CSV upload all task definitions for the given unit
  # POST /api/csv/task_definitions
  def test_csv_upload_all_task_definitions_unit
    data_to_post = {
      unit_id: '1',
      file: upload_file_csv('test_files/csv_test_files/COS10001-Tasks.csv')
    }

    activity_type = FactoryBot.create(:activity_type)
    unit = Unit.find(1)
    unit.add_tutorial_stream('Import-Tasks', 'import-tasks', activity_type)

    # auth_token and username added to header
    add_auth_header_for(user: User.first)

    # perform the POST
    post "/api/csv/task_definitions", data_to_post

    assert_equal 201, last_response.status, last_response_body
    assert_equal 'Assignment 12', TaskDefinition.where(abbreviation: 'A12').first.name

    td = unit.task_definitions.find_by(abbreviation: '5.5D')
    assert_equal 2, td.task_prerequisites.count, last_response_body

    task_prereq1 = td.task_prerequisites.first
    assert_equal 2, task_prereq1.task_status_id

    task_prereq2 = td.task_prerequisites.second
    assert_equal 9, task_prereq2.task_status_id
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

  # 22: Testing for CSV upload of all the students in a unit
  # POST /api/csv/units/{id}
  def test_csv_upload_all_students_in_unit
    Sidekiq::Testing.inline! do
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
      Sidekiq::Testing.fake!
    end
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

  # ####--------------GET tests - Download CSV of all student tasks in this unit------------######

  # 40: Testing for CSV download of all  students tasks in a unit
  # GET /api/csv/units/{id}/task_completion
  def test_download_csv_all_student_tasks_in_unit
    Sidekiq::Testing.inline! do
      unit_id_to_test = '1'
      unit = Unit.find(unit_id_to_test)

      # auth_token and username added to header
      add_auth_header_for(user: User.first)

      # perform the get
      get "/api/csv/units/#{unit_id_to_test}/task_completion"

      # Check for response
      assert_equal 200, last_response.status

      task_completion_stats = unit.task_completion_csv

      assert_not_nil last_response_body['result']

      # Check for CSV data in completed sidekiq job
      assert_equal task_completion_stats, last_response_body['result']
      Sidekiq::Testing.fake!
    end
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
    Sidekiq::Testing.inline! do
      unit_id_to_test = '1'
      unit = Unit.find(unit_id_to_test)

      # Add authentication token to header
      add_auth_header_for(user: User.first)

      # perform the get
      get "/api/csv/units/#{unit_id_to_test}/tutor_assessments"

      # Check for response
      assert_equal 200, last_response.status

      tutor_assesment_stats = unit.tutor_assessment_csv

      assert_not_nil last_response_body['result']

      # Check for CSV data in completed sidekiq job
      assert_equal tutor_assesment_stats, last_response_body['result']
      Sidekiq::Testing.fake!
    end
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

  def test_upload_unit_feedback_chips
    glo = FactoryBot.create(:learning_outcome, abbreviation: 'GGG1', context_type: nil, context_id: nil)
    # Create two identical units with different codes
    unit = FactoryBot.create(:unit, code: 'UNIT1', student_count: 1, inactive_student_count: 0, unenrolled_student_count: 0, part_enrolled_student_count: 0, task_count: 0, outcome_count: 0)
    other_unit = FactoryBot.create(:unit, code: 'UNIT2', student_count: 0, inactive_student_count: 0, unenrolled_student_count: 0, part_enrolled_student_count: 0, task_count: 0, outcome_count: 0)

    ulos = [
      FactoryBot.create(:learning_outcome, context_type: 'Unit', context_id: unit.id, abbreviation: 'ULO1'),
      FactoryBot.create(:learning_outcome, context_type: 'Unit', context_id: unit.id, abbreviation: 'ULO2'),
    ]
    other_ulos = [
      FactoryBot.create(:learning_outcome, context_type: 'Unit', context_id: other_unit.id, abbreviation: 'ULO1'),
    ]
    td = FactoryBot.create(:task_definition, unit: unit, abbreviation: 'P1', outcome_count: 0)
    tlos = [
      FactoryBot.create(:learning_outcome, context_type: 'TaskDefinition', context_id: td.id, abbreviation: 'TLO1'),
      FactoryBot.create(:learning_outcome, context_type: 'TaskDefinition', context_id: td.id, abbreviation: 'TLO2'),
    ]
    other_td = FactoryBot.create(:task_definition, unit: other_unit, abbreviation: 'P1', outcome_count: 0)
    other_tlos = [
      FactoryBot.create(:learning_outcome, context_type: 'TaskDefinition', context_id: other_td.id, abbreviation: 'TLO1'),
      FactoryBot.create(:learning_outcome, context_type: 'TaskDefinition', context_id: other_td.id, abbreviation: 'TLO2'),
    ]

    admin = FactoryBot.create(:user, :admin)
    tutor = FactoryBot.create(:user, :tutor)

    unit.employ_staff(tutor, Role.tutor)

    num_rows_in_csv = 8

    to_test = [
      {
        # Direct to ULO
        url: "/api/units/#{unit.id}/outcomes/#{ulos[0].id}/feedback_chips/csv",
        context: 'Direct - ULO1',
        changed_models: [ulos[0]],
        expected_count: 2,
        unchanged_models: [ulos[1], tlos, other_ulos, other_tlos, glo].flatten
      },
      {
        # To Unit
        url: "/api/units/#{unit.id}/feedback_chips/csv",
        context: 'Unit - all',
        changed_models: [ulos[0], tlos[0]],
        expected_count: 2,
        unchanged_models: [ulos[1], tlos[1], other_ulos, other_tlos, glo].flatten
      },
      {
        # To Task
        url: "/api/task_definitions/#{td.id}/feedback_chips/csv",
        context: 'TaskDef - TLO1',
        changed_models: [tlos[0]],
        expected_count: 2,
        unchanged_models: [ulos, tlos[1], other_ulos, other_tlos, glo].flatten
      }
    ]

    users_can = [
      unit.main_convenor_user,
      admin
    ]
    users_cant = [
      FactoryBot.create(:user, :student),
      FactoryBot.create(:user, :tutor),
      tutor,
      FactoryBot.create(:user, :convenor),
      FactoryBot.create(:user, :auditor)
    ]

    global_chip_count = Feedback::FeedbackChip.global_chips.count
    total_chip_count = Feedback::FeedbackChip.count

    users_can.each do |user|
      add_auth_header_for(user: user)

      to_test.each do |test|
        changed_models = test[:changed_models]
        context = test[:context]
        expected_count = test[:expected_count]
        total_expected = expected_count * changed_models.count
        unchanged_models = test[:unchanged_models]
        url = test[:url]

        [changed_models, unchanged_models].flatten.each do |model|
          assert_equal 0, model.feedback_chips.count
        end

        post url, file: upload_file_csv('test_files/feedback/unit_feedback_chip.csv')
        assert_equal 201, last_response.status, "#{user.role.name} - #{url} - #{last_response.status}"

        assert_equal total_expected, last_response_body['success'].count, "#{context}: #{last_response_body}"
        assert_equal 0, last_response_body['ignored'].count, "#{context}: #{last_response_body}"
        assert_equal num_rows_in_csv - total_expected, last_response_body['errors'].count, "#{context}: #{last_response_body['errors']}"

        changed_models.each do |model|
          assert_equal expected_count, model.feedback_chips.count, "Incorrect number of chips for #{context} - #{model.abbreviation} - #{last_response_body}"
        end
        unchanged_models.each do |unchanged_model|
          assert_equal 0, unchanged_model.feedback_chips.count, "Changes to #{context} affected #{unchanged_model.abbreviation}"
        end

        assert_equal global_chip_count, Feedback::FeedbackChip.global_chips.count, "Changes to #{context} affected global chips"

        changed_models.each do |model|
          model.reload
          model.feedback_chips.destroy_all
        end

        # Make sure we have deleted all new chips
        assert_equal total_chip_count, Feedback::FeedbackChip.count, "Chips not destroyed in - #{context}"
      end
    end

    users_cant.each do |user|
      add_auth_header_for(user: user)
      to_test.each do |test|
        url = test[:url]
        post url, file: upload_file_csv('test_files/feedback/unit_feedback_chip.csv')
        assert_equal 403, last_response.status, "#{user.role.name} - #{url} - #{last_response.status}"
      end
    end
  end

  def test_upload_global_feedback_chips
    # Create things that could be updated
    glo = FactoryBot.create(:learning_outcome, abbreviation: 'GGG1', context_type: nil, context_id: nil)
    unit = FactoryBot.create(:unit, code: 'UNIT1', student_count: 1, inactive_student_count: 0, unenrolled_student_count: 0, part_enrolled_student_count: 0, task_count: 0, outcome_count: 0)
    ulo = FactoryBot.create(:learning_outcome, context_type: 'Unit', context_id: unit.id, abbreviation: 'ULO1')
    td = FactoryBot.create(:task_definition, unit: unit, abbreviation: 'P1', outcome_count: 0)
    tlo = FactoryBot.create(:learning_outcome, context_type: 'TaskDefinition', context_id: td.id, abbreviation: 'TLO1')

    admin = FactoryBot.create(:user, :admin)
    tutor = FactoryBot.create(:user, :tutor)

    unit.employ_staff(tutor, Role.tutor)

    num_rows_in_csv = 8

    to_test = [
      {
        # Direct to ULO
        url: "/api/global/feedback_chips/csv",
        context: 'Direct - GLOs',
        changed_models: [glo],
        expected_count: 2,
        unchanged_models: [ulo, tlo].flatten
      }
    ]

    users_can = [
      admin
    ]
    users_cant = [
      unit.main_convenor_user,
      FactoryBot.create(:user, :student),
      FactoryBot.create(:user, :tutor),
      tutor,
      FactoryBot.create(:user, :convenor),
      FactoryBot.create(:user, :auditor)
    ]

    global_chip_count = Feedback::FeedbackChip.global_chips.count
    total_chip_count = Feedback::FeedbackChip.count

    users_can.each do |user|
      add_auth_header_for(user: user)

      to_test.each do |test|
        changed_models = test[:changed_models]
        context = test[:context]
        expected_count = test[:expected_count]
        total_expected = expected_count * changed_models.count
        unchanged_models = test[:unchanged_models]
        url = test[:url]

        [changed_models, unchanged_models].flatten.each do |model|
          assert_equal 0, model.feedback_chips.count
        end

        post url, file: upload_file_csv('test_files/feedback/unit_feedback_chip.csv')
        assert_equal 201, last_response.status, "#{user.role.name} - #{url} - #{last_response.status}"

        assert_equal total_expected, last_response_body['success'].count, "#{context}: #{last_response_body}"
        assert_equal 0, last_response_body['ignored'].count, "#{context}: #{last_response_body}"
        assert_equal num_rows_in_csv - total_expected, last_response_body['errors'].count, "#{context}: #{last_response_body['errors']}"

        changed_models.each do |model|
          assert_equal expected_count, model.feedback_chips.count, "Incorrect number of chips for #{context} - #{model.abbreviation} - #{last_response_body}"
        end
        unchanged_models.each do |unchanged_model|
          assert_equal 0, unchanged_model.feedback_chips.count, "Changes to #{context} affected #{unchanged_model.abbreviation}"
        end

        changed_models.each do |model|
          model.reload
          model.feedback_chips.destroy_all
        end

        # Make sure we have deleted all new chips
        assert_equal total_chip_count, Feedback::FeedbackChip.count, "Chips not destroyed in - #{context}"
      end
    end
  end

  def test_download_feedback_chips
    # Create two identical units with different codes
    unit = FactoryBot.create(:unit, code: 'UNIT1', student_count: 1, inactive_student_count: 0, unenrolled_student_count: 0, part_enrolled_student_count: 0, task_count: 0, outcome_count: 0)
    ulos = [
      FactoryBot.create(:learning_outcome, context_type: 'Unit', context_id: unit.id, abbreviation: 'ULO1'),
      FactoryBot.create(:learning_outcome, context_type: 'Unit', context_id: unit.id, abbreviation: 'ULO2')
    ]
    td = FactoryBot.create(:task_definition, unit: unit, abbreviation: 'P1', outcome_count: 0)

    admin = FactoryBot.create(:user, :admin)
    tutor = FactoryBot.create(:user, :tutor)

    unit.employ_staff(tutor, Role.tutor)

    to_test = [
      {
        # Direct to ULO
        url: "/api/units/#{unit.id}/outcomes/#{ulos[0].id}/feedback_chips/csv",
        context: 'Direct - ULO1'
      },
      {
        # To Unit
        url: "/api/units/#{unit.id}/feedback_chips/csv",
        context: 'Unit - all'
      },
      {
        # To Task
        url: "/api/task_definitions/#{td.id}/feedback_chips/csv",
        context: 'TaskDef - TLO1'
      }
    ]

    users_can = [
      unit.main_convenor_user,
      admin
    ]
    users_cant = [
      FactoryBot.create(:user, :student),
      FactoryBot.create(:user, :tutor),
      tutor,
      FactoryBot.create(:user, :convenor),
      FactoryBot.create(:user, :auditor)
    ]

    users_can.each do |user|
      add_auth_header_for(user: user)

      to_test.each do |test|
        url = test[:url]
        get url
        assert_equal 200, last_response.status, "#{user.role.name} - #{url} - #{last_response.status}"
      end
    end

    users_cant.each do |user|
      add_auth_header_for(user: user)
      to_test.each do |test|
        url = test[:url]
        post url, file: upload_file_csv('test_files/feedback/unit_feedback_chip.csv')
        assert_equal 403, last_response.status, "#{user.role.name} - #{url} - #{last_response.status}"
      end
    end
  end

  def test_upload_learning_outcomes
    # Create two identical units with different codes
    unit = FactoryBot.create(:unit, code: 'COS10001', student_count: 1, inactive_student_count: 0, unenrolled_student_count: 0, part_enrolled_student_count: 0, task_count: 0, outcome_count: 0)

    td1 = FactoryBot.create(:task_definition, unit: unit, abbreviation: '1.1P', outcome_count: 0)
    td2 = FactoryBot.create(:task_definition, unit: unit, abbreviation: '1.2P', outcome_count: 0)
    td3 = FactoryBot.create(:task_definition, unit: unit, abbreviation: '1.3P', outcome_count: 0)
    td4 = FactoryBot.create(:task_definition, unit: unit, abbreviation: '1.4C', outcome_count: 0)

    admin = FactoryBot.create(:user, :admin)
    tutor = FactoryBot.create(:user, :tutor)

    unit.employ_staff(tutor, Role.tutor)

    # 4 Unit Learning Outcomes (ULOs)
    # 8 Task Learning Outcomes (TLOs)

    num_rows_in_csv = 12

    to_test = [
      {
        # To Task Definition
        # NOTE: We expect all rows to fail, because our Unit outcomes don't exist yet
        # Therefore, out Task outcomes will fail to link to non-existent ULOs
        url: "/api/task_definitions/#{td1.id}/outcomes/csv",
        context: 'TaskDef - (No ULOs to link)',
        expected_success_count: 0,
        expected_error_count: num_rows_in_csv
      },
      {
        # To Unit
        url: "/api/units/#{unit.id}/outcomes/csv",
        context: 'Direct - ULO',
        expected_success_count: num_rows_in_csv, # Both Unit and Task outcomes should be created
        expected_error_count: 0

      },
      {
        # To Task Definition
        url: "/api/task_definitions/#{td1.id}/outcomes/csv",
        context: 'TaskDef 1.1P - TLO',
        expected_success_count: 2, # 2 outcomes for 1.1P
        expected_error_count: 10
      },
      {
        # To Task Definition
        url: "/api/task_definitions/#{td2.id}/outcomes/csv",
        context: 'TaskDef 1.2P - TLO',
        expected_success_count: 3, # 3 outcomes for 1.2P
        expected_error_count: 9
      },
      {
        # To Task Definition
        url: "/api/task_definitions/#{td3.id}/outcomes/csv",
        context: 'TaskDef 1.3P - TLO',
        expected_success_count: 2, # 2 outcomes for 1.3P
        expected_error_count: 10
      },
      {
        # To Task Definition
        url: "/api/task_definitions/#{td4.id}/outcomes/csv",
        context: 'TaskDef 1.4C - TLO',
        expected_success_count: 1, # 1 outcome for 1.4C
        expected_error_count: 11
      }
    ]

    users_can = [
      unit.main_convenor_user,
      admin
    ]

    users_cant = [
      FactoryBot.create(:user, :student),
      FactoryBot.create(:user, :tutor),
      tutor,
      FactoryBot.create(:user, :convenor),
      FactoryBot.create(:user, :auditor)
    ]

    users_can.each do |user|
      add_auth_header_for(user: user)

      to_test.each do |test|
        context = test[:context]
        expected_success_count = test[:expected_success_count]
        expected_error_count = test[:expected_error_count]
        url = test[:url]

        post url, file: upload_file_csv('test_files/COS10001-UnitAndTaskLearningOutcomes.csv')
        assert_equal 201, last_response.status, "#{user.role.name} - #{url} - #{last_response.status}"
        assert_equal expected_success_count, last_response_body['success'].count, "#{context}: #{last_response_body}"
        assert_equal expected_error_count, last_response_body['errors'].count, "#{context}: #{last_response_body}"
      end

      # Ensure we remove out Unit learning outcomes before going to the next user
      unit.learning_outcomes.destroy_all
    end

    users_cant.each do |user|
      add_auth_header_for(user: user)
      to_test.each do |test|
        url = test[:url]
        post url, file: upload_file_csv('test_files/COS10001-UnitAndTaskLearningOutcomes.csv')
        assert_equal 403, last_response.status, "#{user.role.name} - #{url} - #{last_response.status}"
      end
    end
  end

  def test_download_csv_days_tasks_awaiting_feedback_per_tutorial
    Sidekiq::Testing.inline! do
      unit = Unit.first

      # auth_token and username added to header
      add_auth_header_for(user: User.first)

      # perform the get
      get "/api/csv/units/#{unit.id}/tasks_awaiting_feedback"

      # Check for response
      assert_equal 200, last_response.status

      days_awaiting_feedback_csv = unit.days_awaiting_feedback_by_tutorial_csv

      assert_not_nil last_response_body['result']

      # Check for CSV data in completed sidekiq job
      assert_equal days_awaiting_feedback_csv, last_response_body['result']
      Sidekiq::Testing.fake!
    end
  end

  def test_download_csv_times_tasks_assessed
    Sidekiq::Testing.inline! do
      unit = Unit.first

      # auth_token and username added to header
      add_auth_header_for(user: User.first)

      # perform the get
      get "/api/csv/units/#{unit.id}/task_assessment_counts"

      # Check for response
      assert_equal 200, last_response.status, last_response_body['error']

      times_tasks_assessed = unit.times_tasks_have_been_assessed

      assert_not_nil last_response_body['result']

      # Check for CSV data in completed sidekiq job
      assert_equal times_tasks_assessed, last_response_body['result']

      Sidekiq::Testing.fake!
    end
  end
end
