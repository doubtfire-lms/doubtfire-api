require 'test_helper'
require 'json'

class StageApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  # Test: a main convenor can POST a stage
  def test_create_stage_via_post
    unit = FactoryBot.create(:unit)

    data_to_post = {
      title: 'Stage 1',
      order: '1',
      task_definition_id: unit.task_definitions.first.id
    }

    user = unit.main_convenor_user

    stage_count = Stage.count

    # expected_unit = data_to_post[:unit]
    # unit_count = Unit.all.length

    # Add username and auth_token to Header. 
    # Header: a key-value pair sent with the request to the server so that the server can identify the user.
    # The header is the part of the request that contains the username and auth_token.
    add_auth_header_for(user: user)

    # The post that we will be testing.
    post_json '/api/stages', data_to_post

    # Check that the unit name matches what is expected
    assert_equal 201, last_response.status, last_response.body # TTP status code 201 = created

    # Read the new stage from the database
    stage = Stage.last

    # Check that the stage title matches what is expected
    assert_equal data_to_post[:title], stage.title
    # Check that the stage order matches what is expected
    assert_equal data_to_post[:order].to_i, stage.order
    # Check that the stage count has increased by 1
    assert_equal stage_count + 1, Stage.count

    # Delete the unit created for this test from the database
    unit.destroy
  end

  # Test: a student cannot POST a stage
  def test_students_cannot_create_stages
    unit = FactoryBot.create(:unit)

    data_to_post = {
      title: 'Stage 1',
      order: '1',
      task_definition_id: unit.task_definitions.first.id
    }

    user = unit.students.first.user

    stage_count = Stage.count

    # Add username and auth_token to Header
    add_auth_header_for(user: user) # the API request is sent with the student's username and auth_token, to check if the student is allowed to do this

    # The post that we will be testing.
    post_json '/api/stages', data_to_post

    # Check to see if the unit's name matches what was expected
    assert_equal 403, last_response.status, last_response.body

    assert_equal stage_count, Stage.count

    unit.destroy
  end
end
