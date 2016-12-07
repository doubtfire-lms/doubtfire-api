require 'test_helper'

class TaskDefinitionTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_post_invalid_file_tasksheet
    # Get a random unit id to test
    num_of_tasksheets = TaskDefinition.all.length
    test_unit = Unit.order('RANDOM()').first
    test_task_definition_id = test_unit.task_definitions.order('RANDOM()').first.id

    data_to_post = {
      file: 'rubbish_path',
      auth_token: auth_token
    }
    post_json "/api/units/#{test_unit.id}/task_definitions/#{test_task_definition_id}/task_sheet", data_to_post

    assert last_response_body.key?('error')
    assert_equal num_of_tasksheets, TaskDefinition.all.length
  end

  def test_post_tasksheet
    num_of_tasksheets = TaskDefinition.all.length
    test_unit = Unit.order('RANDOM()').first
    test_task_definition_id = test_unit.task_definitions.order('RANDOM()').first.id

    data_to_post = {
      file: Rack::Test::UploadedFile.new('test_files/submissions/00_question.pdf', 'application/pdf')
    }
    post "/api/units/#{test_unit.id}/task_definitions/#{test_task_definition_id}/task_sheet", with_auth_token(data_to_post)

    assert_equal 201, last_response.status
    # assert_equal num_of_tasksheets, TaskDefinition.all.length + 1
  end
end
