require 'test_helper'

class TaskDefinitionTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_post_invalid_file_tasksheet
    test_unit = Unit.order('RANDOM()').first
    test_task_definition_id = test_unit.task_definitions.order('RANDOM()').first.id

    data_to_post = {
      file: 'rubbish_path',
      auth_token: auth_token
    }
    post_json "/api/units/#{test_unit.id}/task_definitions/#{test_task_definition_id}/task_sheet", data_to_post

    assert last_response_body.key?('error')
  end

  def test_post_tasksheet

    test_unit = Unit.where(:administrators == User.first).order('RANDOM()').first
    test_task_definition_id = test_unit.task_definitions.order('RANDOM()').first.id

    data_to_post = {
      file: Rack::Test::UploadedFile.new('test_files/submissions/00_question.pdf', 'application/pdf')
    }

    post "/api/units/#{test_unit.id}/task_definitions/#{test_task_definition_id}/task_sheet", with_auth_token(data_to_post)

    assert_equal 201, last_response.status
  end

  def test_post_task_resources
    test_unit = Unit.where(:administrators == User.first).order('RANDOM()').first
    tdid = test_unit.task_definitions.order('RANDOM()').first.id

    data_to_post = {
      file: Rack::Test::UploadedFile.new('test_files/2015-08-06-COS10001-acain.zip', 'application/zip')
    }
    post "/api/units/#{test_unit.id}/task_definitions/#{tdid}/task_resources", with_auth_token(data_to_post)

    if last_response.status == 403
      puts last_response_body
    end

    assert_equal 201, last_response.status
  end
end
