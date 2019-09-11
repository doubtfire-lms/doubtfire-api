require 'test_helper'

class LectureResourceDownloadsControllerTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end
  
  setup do
    # setup an unauthenticated user
    @user = User.first
  end

  # def test_user_authentication_post
  #   assert      @user.authenticate? 'yilu'
  #   assert_not  @user.authenticate? 'password'
  # end

  # def test_user_authentication_put
  #   # Get clarification for testing requirements
  # end

  # def test_create_user_to_download_resource
  #   profile = {
  #     first_name: 'yi',
  #     last_name: 'lu',
  #     nickname: 'ly',
  #     role_id: 1,
  #     email: 'yilu@test.org',
  #     username: 'ly',
  #     password: 'yilu',
  #     password_confirmation: 'yilu'
  #   }
  #   User.create!(profile)
  #   assert User.last, profile
  # end


  #use unit_id = 1, task_def_id = 1 to test
  def test_lecture_resource_download
    unit_count = Unit.all.length
    test_unit_count = Unit.all.first
    test_unitID = test_unit_count.id
    get with_auth_token "api/units/#{test_unitID}/all_resources"
    assert_equal 200, last_response.status
  end

  #test visit without authenciated
  # def test_lecture_resource_download_withoutAuthenciated
  #   get "api/units/1/all_resources"
  #   assert_equal 401, last_response.status
  # end

  def test_render_json_in_resource_download
    unit_count = Unit.all.length
    test_unit_count = Unit.all.first
    test_unitID = test_unit_count.id
    get "api/units/#{test_unitID}/all_resources"
    assert_equal 419, last_response.status
    #check unit number
    puts  test_unitID
  end

  def test_task_submission_pdfs
    unit_count = Unit.all.length
    test_unit_count = Unit.all.first
    test_unitID = test_unit_count.id

    task_number = Task.all.length
    test_task_number = Task.all.first
    test_taskID = test_unit_count.id
    #check task number
    puts test_taskID

    get with_auth_token "api/submission/unit/#{test_unitID}/task_definitions/#{test_taskID}/student_pdfs"
    assert_equal 200, last_response.status
  end

  #without auth token to test
  def test_render_json_in_task_submission
    unit_count = Unit.all.length
    test_unit_count = Unit.all.first
    test_unitID = test_unit_count.id

    task_number = Task.all.length
    test_task_number = Task.all.first
    test_taskID = test_unit_count.id

    get "api/submission/unit/#{test_unitID}/task_definitions/#{test_taskID}/student_pdfs"
    assert_equal 419, last_response.status
  end

  #test no file to download
  def test_no_file_to_download
    unit_count = Unit.all.length
    test_unit_count = Unit.all.first
    test_unitID = test_unit_count.id

    task_number = Task.all.length
    test_task_number = Task.all.first
    test_taskID = test_unit_count.id

    get with_auth_token "api/submission/unit/#{test_unitID}/task_definitions/#{test_taskID}/download_submissions"
    assert_equal 200, last_response.status
  end

  def test_render_json_in_task_download
    unit_count = Unit.all.length
    test_unit_count = Unit.all.first
    test_unitID = test_unit_count.id

    task_number = Task.all.length
    test_task_number = Task.all.first
    test_taskID = test_unit_count.id

    get "api/submission/unit/#{test_unitID}/task_definitions/#{test_taskID}/download_submissions"
    assert_equal 419, last_response.status
  end

  def test_portfolio_download
    unit_count = Unit.all.length
    test_unit_count = Unit.all.first
    test_unitID = test_unit_count.id
    get with_auth_token "api/submission/unit/#{test_unitID}/portfolio"
    assert_equal 200, last_response.status
  end

  def test_render_json_in_portfolio_download
    unit_count = Unit.all.length
    test_unit_count = Unit.all.first
    test_unitID = test_unit_count.id
    get "api/submission/unit/#{test_unitID}/portfolio"
    assert_equal 419, last_response.status
  end
end