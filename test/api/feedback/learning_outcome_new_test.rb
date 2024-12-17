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
    assert_equal 200, last_response.status
  ensure
    unit.destroy
    learning_outcome1.destroy
    learning_outcome2.destroy
    learning_outcome3.destroy
  end

  def test_get_global_outcomes
    unit = FactoryBot.create(:unit, name: 'i like units', code: 'abcde', description: 'test unit')
    learning_outcome1 = FactoryBot.create(:learning_outcome, context_id: nil, context_type: nil, abbreviation: 'test1', short_description: 'sd', full_outcome_description: 'fod')
    learning_outcome2 = FactoryBot.create(:learning_outcome, context_id: nil, context_type: nil, abbreviation: 'test2', short_description: 'sd', full_outcome_description: 'fod')
    learning_outcome3 = FactoryBot.create(:learning_outcome, context_id: nil, context_type: nil, abbreviation: 'test3', short_description: 'sd', full_outcome_description: 'fod')
    add_auth_header_for user: unit.main_convenor_user
    get "api/global/outcomes"
    assert_equal 200, last_response.status
  ensure
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
  ensure
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
  ensure
    unit.destroy
    learning_outcome.destroy
  end

  def test_delete_outcome
    unit = FactoryBot.create(:unit, name: 'i like units', code: 'abcde', description: 'test unit')
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit', abbreviation: 'abbreviation', short_description: 'short_description', full_outcome_description: 'full_outcome_description')
    add_auth_header_for user: User.first
    delete "api/units/#{unit.id}/outcomes/#{learning_outcome.id}"
    assert_equal 204, last_response.status
  ensure
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
  ensure
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
    assert_equal 201, last_response.status
  ensure
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
    assert_equal 200, last_response.status
  ensure
    task_definition.destroy
    learning_outcome.destroy
  end

  def test_delete_task_definition_learning_outcome
    task_definition = FactoryBot.create(:task_definition)
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: task_definition.id, context_type: 'TaskDefinition', abbreviation: 'abbr', short_description: 'sd', full_outcome_description: 'fod')
    add_auth_header_for user: User.first
    delete "api/task_definitions/#{task_definition.id}/outcomes/#{learning_outcome.id}"
    assert_equal 204, last_response.status
  ensure
    task_definition.destroy
  end

  def test_get_all_feedback_chips_for_outcome
    task_definition = TaskDefinition.first
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: task_definition.id, context_type: 'TaskDefinition', abbreviation: 'abbr', short_description: 'sd', full_outcome_description: 'fod')
    group_chip1 = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id, parent_chip_id: nil, chip_text: 'chip1')
    template_chip2 = FactoryBot.create(:feedback_template_chip, learning_outcome_id: learning_outcome.id, parent_chip_id: group_chip1.id, chip_text: 'chip2')
    template_chip3 = FactoryBot.create(:feedback_template_chip, learning_outcome_id: learning_outcome.id, parent_chip_id: group_chip1.id, chip_text: 'chip3')
    add_auth_header_for user: User.first
    get "api/task_definitions/#{task_definition.id}/outcomes/#{learning_outcome.id}/feedback_chips"
    assert_equal 200, last_response.status
  ensure
    learning_outcome.destroy
    group_chip1.destroy
    template_chip2.destroy
    template_chip3.destroy
  end

  def test_create_learning_outcome_links
    task_definition = FactoryBot.create(:task_definition)
    unit = FactoryBot.create(:unit, name: 'i like units', code: 'abcde', description: 'test unit')
    target_learning_outcome = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit', abbreviation: 'target', short_description: 'target learning outcome', full_outcome_description: 'this outcome will be linked to source')
    target_learning_outcome2 = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit', abbreviation: 'target2', short_description: 'target learning outcome 2', full_outcome_description: 'this outcome will be linked to source')
    data_to_post = {
      context_id: task_definition.id,
      context_type: 'TaskDefinition',
      abbreviation: 'source',
      short_description: 'source learning outcome',
      full_outcome_description: 'this outcome will be linked to target',
      linked_outcome_ids: [target_learning_outcome.id, target_learning_outcome2.id]
    }
    add_auth_header_for user: User.first
    post_json "api/task_definitions/#{task_definition.id}/outcomes", data_to_post
    assert_equal 201, last_response.status
  ensure
    unit.destroy
    target_learning_outcome.destroy
    target_learning_outcome2.destroy
    task_definition.destroy
  end

  def test_update_learning_outcome_links
    task_definition = FactoryBot.create(:task_definition)
    unit = FactoryBot.create(:unit, name: 'i like units', code: 'abcde', description: 'test unit')
    target_learning_outcome = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit', abbreviation: 'target', short_description: 'target learning outcome', full_outcome_description: 'this outcome will be linked to source')
    target_learning_outcome2 = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit', abbreviation: 'target2', short_description: 'target learning outcome 2', full_outcome_description: 'this outcome will be linked to source')
    source_learning_outcome = FactoryBot.create(:learning_outcome, context_id: task_definition.id, context_type: 'TaskDefinition', abbreviation: 'source', short_description: 'source learning outcome', full_outcome_description: 'this outcome will be linked to target')
    data_to_put = {
      abbreviation: 'changed abbr',
      linked_outcome_ids: [target_learning_outcome.id, target_learning_outcome2.id]
    }
    add_auth_header_for user: User.first
    put_json "api/task_definitions/#{task_definition.id}/outcomes/#{source_learning_outcome.id}", data_to_put
    assert_equal 200, last_response.status
  ensure
    unit.destroy
    target_learning_outcome.destroy
    target_learning_outcome2.destroy
    source_learning_outcome.destroy
    task_definition.destroy
  end
end
