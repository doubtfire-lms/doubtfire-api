require 'test_helper'
require 'json'

class StageApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  # CRUD = create, read, update, delete
  #        post, get, put, delete
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

    # Add username and auth_token to Header
    add_auth_header_for(user: user)

    # The post that we will be testing.
    post_json '/api/stages', data_to_post

    # Check to see if the unit's name matches what was expected
    assert_equal 201, last_response.status, last_response.body

    # Read the new stage from the database
    stage = Stage.last

    # Check that the stage's title matches what was expected
    assert_equal data_to_post[:title], stage.title
    # Check that the stage's order matches what was expected
    assert_equal data_to_post[:order].to_i, stage.order

    assert_equal stage_count + 1, Stage.count

    unit.destroy
  end

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
    add_auth_header_for(user: user)

    # The post that we will be testing.
    post_json '/api/stages', data_to_post

    # Check to see if the unit's name matches what was expected
    assert_equal 403, last_response.status, last_response.body

    assert_equal stage_count, Stage.count

    unit.destroy
  end
end
