require 'test_helper'

class LearningOutcomeNewTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_get_all_outcomes
    unit = FactoryBot.create(:unit, name: 'i like units', code: 'abcde', description: 'test unit')
    learning_outcome1 = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit', abbreviation: 'test1', short_description: 'sd', full_outcome_description: 'fod')
    learning_outcome2 = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit', abbreviation: 'test2', short_description: 'sd', full_outcome_description: 'fod')
    learning_outcome3 = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit', abbreviation: 'test3', short_description: 'sd', full_outcome_description: 'fod')
    add_auth_header_for user: User.first
    get "api/units/#{unit.id}/outcomes"
    puts last_response.body
    assert_equal 200, last_response.status
    unit.destroy
    learning_outcome1.destroy
    learning_outcome2.destroy
    learning_outcome3.destroy
  end

  def test_get_global_outcomes
    learning_outcome1 = FactoryBot.create(:learning_outcome, context_id: nil, context_type: nil, abbreviation: 'test1', short_description: 'sd', full_outcome_description: 'fod')
    learning_outcome2 = FactoryBot.create(:learning_outcome, context_id: nil, context_type: nil, abbreviation: 'test2', short_description: 'sd', full_outcome_description: 'fod')
    learning_outcome3 = FactoryBot.create(:learning_outcome, context_id: nil, context_type: nil, abbreviation: 'test3', short_description: 'sd', full_outcome_description: 'fod')
    add_auth_header_for user: User.first
    get "api/global/outcomes"
    puts last_response.body
    assert_equal 200, last_response.status
    learning_outcome1.destroy
    learning_outcome2.destroy
    learning_outcome3.destroy
  end

  def test_default_create
    learning_outcome = FactoryBot.create(:learning_outcome)
    assert learning_outcome.valid?
  end

  def test_specific_create
    unit = FactoryBot.create(:unit, name: 'i like units', code: 'abcde', description: 'test unit')
    data_to_post = {
      context_type: 'Unit',
      context_id: unit.id,
      abbreviation: 'changed abbreviation',
      short_description: 'changed short_description',
      full_outcome_description: 'changed full_outcome_description'
    }
    add_auth_header_for user: User.first
    post_json "api/units/#{unit.id}/outcomes", data_to_post
    assert_equal 201, last_response.status
    unit.destroy
  end

  def test_update_outcome
    unit = FactoryBot.create(:unit, name: 'i like units', code: 'abcde', description: 'test unit')
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit', abbreviation: 'abbreviation', short_description: 'short_description', full_outcome_description: 'full_outcome_description')
    data_to_put = {
      abbreviation: 'changed abbreviation',
      short_description: 'changed short_description',
      full_outcome_description: 'changed full_outcome_description'
    }
    add_auth_header_for user: User.first
    put_json "api/units/#{unit.id}/outcomes/#{learning_outcome.id}", data_to_put
    assert_equal 200, last_response.status
    unit.destroy
    learning_outcome.destroy
  end

  def test_delete_outcome
    unit = FactoryBot.create(:unit, name: 'i like units', code: 'abcde', description: 'test unit')
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit', abbreviation: 'abbreviation', short_description: 'short_description', full_outcome_description: 'full_outcome_description')
    add_auth_header_for user: User.first
    delete "api/units/#{unit.id}/outcomes/#{learning_outcome.id}"
    assert_equal 204, last_response.status
    unit.destroy
  end

  def test_create_global_outcome
    data_to_post = {
      context_type: nil,
      context_id: nil,
      abbreviation: 'GLO2',
      short_description: 'global short_description',
      full_outcome_description: 'global full_outcome_description'
    }
    add_auth_header_for user: User.first
    post_json "api/global/outcomes", data_to_post
    puts last_response.body
    assert_equal 201, last_response.status
  end

  def test_update_global_outcome
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: nil, context_type: nil, abbreviation: 'GLO2', short_description: 'global short_description', full_outcome_description: 'global full_outcome_description')
    data_to_put = {
      abbreviation: 'changed abbreviation',
      short_description: 'changed short_description',
      full_outcome_description: 'changed full_outcome_description'
    }
    add_auth_header_for user: User.first
    put_json "api/global/outcomes/#{learning_outcome.id}", data_to_put
    assert_equal 200, last_response.status
    learning_outcome.destroy
  end

  def test_create_task_definition_learning_outcome
    task_definition = FactoryBot.create(:task_definition)
    data_to_post = {
      context_type: 'TaskDefinition',
      context_id: task_definition.id,
      abbreviation: 'abbr',
      short_description: 'sd',
      full_outcome_description: 'fod'
    }
    add_auth_header_for user: User.first
    post_json "api/task_definitions/#{task_definition.id}/outcomes", data_to_post
    puts last_response.body
    assert_equal 201, last_response.status
    task_definition.destroy
  end

  def test_update_task_definition_learning_outcome
    task_definition = FactoryBot.create(:task_definition)
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: task_definition.id, context_type: 'TaskDefinition', abbreviation: 'abbr', short_description: 'sd', full_outcome_description: 'fod')
    data_to_put = {
      abbreviation: 'changed abbreviation',
      short_description: 'changed short_description',
      full_outcome_description: 'changed full_outcome_description'
    }
    add_auth_header_for user: User.first
    put_json "api/task_definitions/#{task_definition.id}/outcomes/#{learning_outcome.id}", data_to_put
    puts last_response.body
    assert_equal 200, last_response.status
    task_definition.destroy
    learning_outcome.destroy
  end

  def test_delete_task_definition_learning_outcome
    task_definition = FactoryBot.create(:task_definition)
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: task_definition.id, context_type: 'TaskDefinition', abbreviation: 'abbr', short_description: 'sd', full_outcome_description: 'fod')
    add_auth_header_for user: User.first
    delete "api/task_definitions/#{task_definition.id}/outcomes/#{learning_outcome.id}"
    assert_equal 204, last_response.status
    task_definition.destroy
  end

end
