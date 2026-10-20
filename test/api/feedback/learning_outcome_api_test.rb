require 'test_helper'

class LearningOutcomeApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_auth_for_create_edit_unit_learning_outcome
    unit = FactoryBot.create(:unit, with_students: false, outcome_count: 0, task_count: 0)
    td = FactoryBot.create(:task_definition, unit: unit, outcome_count: 0)
    admin = FactoryBot.create(:user, :admin)
    tutor = FactoryBot.create(:user, :tutor)

    unit.employ_staff(tutor, Role.tutor)

    unit_contexts = [
      {
        model: unit,
        context_type: 'units'
      },
      {
        model: td,
        context_type: 'task_definitions'
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

    data_to_post = {
      abbreviation: 'ULO9',
      short_description: 'learning outcome short description',
      full_outcome_description: 'Long description of learning outcome',
    }

    data_to_put = {
      abbreviation: 'NLO9',
      short_description: 'new learning outcome short description',
      full_outcome_description: 'New long description of learning outcome',
    }

    users_can.each do |user|
      add_auth_header_for user: user
      unit_contexts.each do |context|
        post_json "api/#{context[:context_type]}/#{context[:model].id}/outcomes", data_to_post

        assert_equal 201, last_response.status, "#{user.role.name} #{context[:context_type]}: #{last_response_body}"
        assert_equal 1, context[:model].learning_outcomes.count

        new_outcome = LearningOutcome.find(last_response_body['id'])

        put_json "api/#{context[:context_type]}/#{context[:model].id}/outcomes/#{new_outcome.id}", data_to_put
        assert_equal 200, last_response.status, "User #{user.role.name} should be able to update learning outcomes in #{context[:context_type]}"

        # Clean up
        LearningOutcome.last.destroy
      end
    end

    unit_contexts[0][:lo] = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit', abbreviation: 'ULO9', short_description: 'learning outcome short description', full_outcome_description: 'Long description of learning outcome')
    unit_contexts[1][:lo] = FactoryBot.create(:learning_outcome, context_id: td.id, context_type: 'TaskDefinition', abbreviation: 'ULO9', short_description: 'learning outcome short description', full_outcome_description: 'Long description of learning outcome')

    total_outcome_count = LearningOutcome.count

    users_cant.each do |user|
      add_auth_header_for user: user
      unit_contexts.each do |context|
        post_json "api/#{context[:context_type]}/#{context[:model].id}/outcomes", data_to_post
        assert_equal 403, last_response.status, "User #{user.role.name} should not be able to create learning outcomes. #{last_response.inspect}"
        assert_equal 1, context[:model].learning_outcomes.count
        assert_equal total_outcome_count, LearningOutcome.count

        put_json "api/#{context[:context_type]}/#{context[:model].id}/outcomes/#{context[:lo].id}", data_to_put
        assert_equal 403, last_response.status, "User #{user.role.name} should not be able to update learning outcomes in #{context[:context_type]}"
      end
    end
  end

  def test_get_global_outcomes
    learning_outcome1 = FactoryBot.create(:learning_outcome, context_id: nil, context_type: nil, abbreviation: 'test1', short_description: 'sd', full_outcome_description: 'fod')
    learning_outcome2 = FactoryBot.create(:learning_outcome, context_id: nil, context_type: nil, abbreviation: 'test2', short_description: 'sd', full_outcome_description: 'fod')
    learning_outcome3 = FactoryBot.create(:learning_outcome, context_id: nil, context_type: nil, abbreviation: 'test3', short_description: 'sd', full_outcome_description: 'fod')
    add_auth_header_for user: User.first
    get "api/global/outcomes"
    assert_equal 200, last_response.status
    assert_equal LearningOutcome.global_outcomes.count, last_response_body.count

    last_response_body.each do |outcome|
      model = LearningOutcome.find(outcome['id'])
      assert_json_matches_model model, outcome, %w(id context_id context_type abbreviation short_description full_outcome_description)
    end
  end

  def test_default_create
    learning_outcome = FactoryBot.create(:learning_outcome)
    assert learning_outcome.valid?
  end

  def test_specific_create
    unit = FactoryBot.create(:unit, name: 'i like units', code: 'abcde', description: 'test unit', outcome_count: 0, with_students: false, task_count: 0)
    data_to_post = {
      context_type: 'Unit',
      context_id: unit.id,
      abbreviation: 'ULO1',
      short_description: 'changed short_description',
      full_outcome_description: 'changed full_outcome_description'
    }
    add_auth_header_for user: unit.main_convenor_user
    post_json "api/units/#{unit.id}/outcomes", data_to_post
    assert_equal 201, last_response.status, last_response_body
  ensure
    unit.destroy
  end

  def test_update_outcome
    unit = FactoryBot.create(:unit, name: 'i like units', code: 'abcde', description: 'test unit')
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit', abbreviation: 'ULO0', short_description: 'short_description', full_outcome_description: 'full_outcome_description')
    data_to_put = {
      abbreviation: 'ULO9',
      short_description: 'changed short_description',
      full_outcome_description: 'changed full_outcome_description'
    }
    add_auth_header_for user: User.first
    put_json "api/units/#{unit.id}/outcomes/#{learning_outcome.id}", data_to_put
    assert_equal 200, last_response.status

    learning_outcome.reload
    assert_equal 'ULO9', learning_outcome.abbreviation
    assert_equal 'changed short_description', learning_outcome.short_description
    assert_equal 'changed full_outcome_description', learning_outcome.full_outcome_description
    assert_json_matches_model learning_outcome, last_response_body, %w[id context_id context_type abbreviation short_description full_outcome_description]
  end

  def test_delete_outcome
    unit = FactoryBot.create(:unit, name: 'i like units', code: 'abcde', description: 'test unit', with_students: false, outcome_count: 0, task_count: 0)
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit', abbreviation: 'ULO1', short_description: 'short_description', full_outcome_description: 'full_outcome_description')
    add_auth_header_for user: User.first
    delete "api/units/#{unit.id}/outcomes/#{learning_outcome.id}"
    assert_equal 204, last_response.status

    assert_equal 0, unit.learning_outcomes.count
  ensure
    unit.destroy
  end

  def test_create_global_outcome
    data_to_post = {
      context_type: nil,
      context_id: nil,
      abbreviation: 'TST2',
      short_description: 'global short_description',
      full_outcome_description: 'global full_outcome_description'
    }
    add_auth_header_for user: User.first

    count = LearningOutcome.global_outcomes.count

    post_json "api/global/outcomes", data_to_post
    assert_equal 201, last_response.status

    assert_equal count + 1, LearningOutcome.global_outcomes.count
    assert_json_matches_model LearningOutcome.global_outcomes.last, last_response_body, %w[id context_id context_type abbreviation short_description full_outcome_description]
  end

  def test_update_global_outcome
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: nil, context_type: nil, abbreviation: 'TST1', short_description: 'global short_description', full_outcome_description: 'global full_outcome_description')
    data_to_put = {
      abbreviation: 'ABR1',
      short_description: 'changed short_description',
      full_outcome_description: 'changed full_outcome_description'
    }
    add_auth_header_for user: User.first

    put_json "api/global/outcomes/#{learning_outcome.id}", data_to_put
    assert_equal 200, last_response.status

    assert learning_outcome
    learning_outcome.reload
    assert_equal 'ABR1', learning_outcome.abbreviation
    assert_equal 'changed short_description', learning_outcome.short_description
    assert_equal 'changed full_outcome_description', learning_outcome.full_outcome_description
    assert_json_matches_model learning_outcome, last_response_body, %w[id context_id context_type abbreviation short_description full_outcome_description]
  end

  def test_create_task_definition_learning_outcome
    task_definition = FactoryBot.create(:task_definition, outcome_count: 0)
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

    assert_json_matches_model LearningOutcome.last, last_response_body, %w[id context_id context_type abbreviation short_description full_outcome_description]
    assert_equal 1, task_definition.learning_outcomes.count
  end

  def test_update_task_definition_learning_outcome
    task_definition = FactoryBot.create(:task_definition)
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: task_definition.id, context_type: 'TaskDefinition', abbreviation: 'abbr', short_description: 'sd', full_outcome_description: 'fod')
    data_to_put = {
      abbreviation: '12345',
      short_description: 'changed short_description',
      full_outcome_description: 'changed full_outcome_description'
    }
    add_auth_header_for user: User.first
    put_json "api/task_definitions/#{task_definition.id}/outcomes/#{learning_outcome.id}", data_to_put
    assert_equal 200, last_response.status

    learning_outcome.reload
    assert_equal '12345', learning_outcome.abbreviation
    assert_equal 'changed short_description', learning_outcome.short_description
    assert_equal 'changed full_outcome_description', learning_outcome.full_outcome_description
    assert_json_matches_model learning_outcome, last_response_body, %w[id context_id context_type abbreviation short_description full_outcome_description]
  end

  def test_delete_task_definition_learning_outcome
    task_definition = FactoryBot.create(:task_definition, outcome_count: 0)
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: task_definition.id, context_type: 'TaskDefinition', abbreviation: 'abbr', short_description: 'sd', full_outcome_description: 'fod')
    add_auth_header_for user: User.first

    delete "api/task_definitions/#{task_definition.id}/outcomes/#{learning_outcome.id}"
    assert_equal 204, last_response.status
    assert_equal 0, task_definition.learning_outcomes.count
  end

  def test_create_learning_outcome_links
    unit = FactoryBot.create(:unit, name: 'i like units', code: 'abcde', description: 'test unit')
    task_definition = FactoryBot.create(:task_definition, outcome_count: 0, unit: unit)
    target_learning_outcome = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit', abbreviation: 'TGT1', short_description: 'target learning outcome', full_outcome_description: 'this outcome will be linked to source')
    target_learning_outcome2 = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit', abbreviation: 'TGT2', short_description: 'target learning outcome 2', full_outcome_description: 'this outcome will be linked to source')
    data_to_post = {
      context_id: task_definition.id,
      context_type: 'TaskDefinition',
      abbreviation: 'TGT3',
      short_description: 'source learning outcome',
      full_outcome_description: 'this outcome will be linked to target',
      linked_outcome_ids: [target_learning_outcome.id, target_learning_outcome2.id]
    }

    count = LearningOutcomeLink.count

    add_auth_header_for user: User.first
    post_json "api/task_definitions/#{task_definition.id}/outcomes", data_to_post
    assert_equal 201, last_response.status

    assert LearningOutcomeLink.find_by(source_id: LearningOutcome.last.id, target_id: target_learning_outcome.id).valid?
    assert LearningOutcomeLink.find_by(source_id: LearningOutcome.last.id, target_id: target_learning_outcome2.id).valid?

    assert_equal count + 2, LearningOutcomeLink.count
  end

  def test_overwrite_linked_learning_outcomes
    unit = FactoryBot.create(:unit, name: 'i like units', code: 'abcde', description: 'test unit')
    task_definition = FactoryBot.create(:task_definition, outcome_count: 0, unit: unit)
    target_learning_outcome = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit', abbreviation: 'TGT1', short_description: 'target learning outcome', full_outcome_description: 'this outcome will be linked to source')
    target_learning_outcome2 = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit', abbreviation: 'TGT2', short_description: 'target learning outcome 2', full_outcome_description: 'this outcome will be linked to source')
    data_to_post = {
      context_id: task_definition.id,
      context_type: 'TaskDefinition',
      abbreviation: 'TGT3',
      short_description: 'source learning outcome',
      full_outcome_description: 'this outcome will be linked to target',
      linked_outcome_ids: [target_learning_outcome.id, target_learning_outcome2.id]
    }
    add_auth_header_for user: User.first
    post_json "api/task_definitions/#{task_definition.id}/outcomes", data_to_post

    source_outcome = LearningOutcome.last

    assert LearningOutcomeLink.find_by(source_id: source_outcome.id, target_id: target_learning_outcome.id)
    assert LearningOutcomeLink.find_by(source_id: source_outcome.id, target_id: target_learning_outcome2.id)

    target_learning_outcome3 = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit', abbreviation: 'TGT4', short_description: 'target learning outcome 3', full_outcome_description: 'this outcome will be linked to source')

    data_to_put = {
      linked_outcome_ids: [target_learning_outcome.id, target_learning_outcome3.id]
    }
    put_json "api/task_definitions/#{task_definition.id}/outcomes/#{task_definition.learning_outcomes.first.id}", data_to_put
    assert_equal 200, last_response.status

    assert LearningOutcomeLink.find_by(source_id: source_outcome.id, target_id: target_learning_outcome.id)
    assert_nil LearningOutcomeLink.find_by(source_id: source_outcome.id, target_id: target_learning_outcome2.id)
    assert LearningOutcomeLink.find_by(source_id: source_outcome.id, target_id: target_learning_outcome3.id)
  end

  def test_delete_chips_for_learning_outcome
    task_definition = FactoryBot.create(:task_definition)
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: task_definition.id, context_type: 'TaskDefinition', abbreviation: 'abbr', short_description: 'sd', full_outcome_description: 'fod')
    group_chip1 = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id, parent_chip_id: nil, chip_text: 'chip1')
    template_chip2 = FactoryBot.create(:feedback_template_chip, learning_outcome_id: learning_outcome.id, parent_chip_id: group_chip1.id, chip_text: 'chip2')
    template_chip3 = FactoryBot.create(:feedback_template_chip, learning_outcome_id: learning_outcome.id, parent_chip_id: group_chip1.id, chip_text: 'chip3')
    add_auth_header_for user: User.first

    deleted_models = [learning_outcome, group_chip1, template_chip2, template_chip3]

    deleted_models.each do |model|
      assert model.valid?
    end

    delete "api/task_definitions/#{task_definition.id}/outcomes/#{learning_outcome.id}"
    assert_equal 204, last_response.status

    deleted_models.each do |model|
      assert_raises ActiveRecord::RecordNotFound do
        model.reload
      end
    end
  end

  def test_unit_rollover
    # Create a unit with learning outcomes
    global_learning_outcome = FactoryBot.create(:learning_outcome, context_id: nil, context_type: nil, abbreviation: 'nglo')
    original_unit = FactoryBot.create(:unit, name: 'rollver unit', code: 'abcde', description: 'test unit to be rolled over') # When creating unit, it generates 2 random outcomes in addition to below
    original_task_definition = FactoryBot.create(:task_definition, unit: original_unit, outcome_count: 0)
    original_lo1 = FactoryBot.create(:learning_outcome, context_id: original_unit.id, context_type: 'Unit', abbreviation: 'olo1', short_description: 'sd', full_outcome_description: 'fod')
    original_lo2 = FactoryBot.create(:learning_outcome, context_id: original_unit.id, context_type: 'Unit', abbreviation: 'olo2', short_description: 'sd', full_outcome_description: 'fod')
    original_lo3 = FactoryBot.create(:learning_outcome, context_id: original_unit.id, context_type: 'Unit', abbreviation: 'olo3', short_description: 'sd', full_outcome_description: 'fod')

    # Create chips for each learning outcome
    # LO1
    group_chip_lo1 = FactoryBot.create(:feedback_group_chip, learning_outcome_id: original_lo1.id, chip_text: 'group chip lo1')
    template_chip_lo1 = FactoryBot.create(:feedback_template_chip, learning_outcome_id: original_lo1.id, parent_chip_id: group_chip_lo1.id, chip_text: 'template chip lo1')
    template_chip2_lo1 = FactoryBot.create(:feedback_template_chip, learning_outcome_id: original_lo1.id, parent_chip_id: group_chip_lo1.id, chip_text: 'template chip 2 lo1')
    # LO2
    group_chip_lo2 = FactoryBot.create(:feedback_group_chip, learning_outcome_id: original_lo2.id, chip_text: 'group chip lo2')
    template_chip_lo2 = FactoryBot.create(:feedback_template_chip, learning_outcome_id: original_lo2.id, parent_chip_id: group_chip_lo2.id, chip_text: 'template chip lo2')
    template_chip2_lo2 = FactoryBot.create(:feedback_template_chip, learning_outcome_id: original_lo2.id, parent_chip_id: group_chip_lo2.id, chip_text: 'template chip 2 lo2')
    # LO3
    group_chip_lo3 = FactoryBot.create(:feedback_group_chip, learning_outcome_id: original_lo3.id, chip_text: 'group chip lo3')
    template_chip_lo3 = FactoryBot.create(:feedback_template_chip, learning_outcome_id: original_lo3.id, parent_chip_id: group_chip_lo3.id, chip_text: 'template chip lo3')
    template_chip2_lo3 = FactoryBot.create(:feedback_template_chip, learning_outcome_id: original_lo3.id, parent_chip_id: group_chip_lo3.id, chip_text: 'template chip 2 lo3')

    # Create lo for task definition
    td_lo = FactoryBot.create(:learning_outcome, context_id: original_task_definition.id, context_type: 'TaskDefinition', abbreviation: 'td_lo', short_description: 'sd', full_outcome_description: 'fod')
    group_chip_td_lo = FactoryBot.create(:feedback_group_chip, learning_outcome_id: td_lo.id, chip_text: 'group chip td_lo')
    template_chip_td_lo = FactoryBot.create(:feedback_template_chip, learning_outcome_id: td_lo.id, parent_chip_id: group_chip_td_lo.id, chip_text: 'template chip td_lo')
    template_chip2_td_lo = FactoryBot.create(:feedback_template_chip, learning_outcome_id: td_lo.id, parent_chip_id: group_chip_td_lo.id, chip_text: 'TCTD2')

    # Create links between learning outcomes
    # lo1 to global lo
    LearningOutcomeLink.create!(source_id: original_lo1.id, target_id: global_learning_outcome.id)
    # td to ulo
    LearningOutcomeLink.create!(source_id: td_lo.id, target_id: original_lo2.id)

    original_unit.reload
    original_task_definition.reload

    new_unit = original_unit.rollover(TeachingPeriod.find(2), nil, nil, nil)
    new_td = new_unit.task_definitions.find_by(name: original_task_definition.name)
    new_td_lo = new_td.learning_outcomes.find_by(abbreviation: td_lo.abbreviation)

    assert_equal 5, new_unit.learning_outcomes.count, 'New unit should have 5 learning outcomes'
    auto1, auto2, new_lo1, new_lo2, new_lo3 = new_unit.learning_outcomes.order(:id)
    assert_equal original_lo1.abbreviation, new_lo1.abbreviation, 'New learning outcome 1 should have the same abbreviation as the original learning outcome 1'
    assert_equal original_lo2.abbreviation, new_lo2.abbreviation, 'New learning outcome 2 should have the same abbreviation as the original learning outcome 2'
    assert_equal original_lo3.abbreviation, new_lo3.abbreviation, 'New learning outcome 3 should have the same abbreviation as the original learning outcome 3'

    [new_lo1, new_lo2, new_lo3].each do |lo|
      assert_equal lo.feedback_chips.count, 3, 'Each learning outcome should have 3 feedback chips'
    end

    new_lo1_feedback_chips = new_lo1.feedback_chips
    new_lo2_feedback_chips = new_lo2.feedback_chips
    new_lo3_feedback_chips = new_lo3.feedback_chips

    new_lo1_feedback_chips.each do |chip|
      assert_equal chip.learning_outcome_id, new_lo1.id, 'Each feedback chip should have the correct learning outcome id'
    end

    new_lo2_feedback_chips.each do |chip|
      assert_equal chip.learning_outcome_id, new_lo2.id, 'Each feedback chip should have the correct learning outcome id'
    end

    new_lo3_feedback_chips.each do |chip|
      assert_equal chip.learning_outcome_id, new_lo3.id, 'Each feedback chip should have the correct learning outcome id'
    end

    assert_equal 1, new_td.learning_outcomes.count, 'New task definition should have 1 learning outcome'
    new_td_lo = new_td.learning_outcomes.first
    assert_equal new_td_lo.abbreviation, td_lo.abbreviation, 'New task definition learning outcome should have the same abbreviation as the original task definition learning outcome'

    assert_equal new_td_lo.feedback_chips.count, 3, 'New task definition learning outcome should have 3 feedback chips'
    new_td_lo_feedback_chips = new_td_lo.feedback_chips

    new_td_lo_feedback_chips.each do |chip|
      assert_equal chip.learning_outcome_id, new_td_lo.id, 'Each feedback chip should have the correct learning outcome id'
    end

    copied_group_chip = new_td_lo.feedback_group_chips.find_by(chip_text: group_chip_td_lo.chip_text)
    copied_template_chip = new_td_lo.feedback_template_chips.find_by(chip_text: template_chip_td_lo.chip_text)

    assert_not_nil copied_group_chip, 'The task learning outcome feedback group should be copied'
    assert_not_nil copied_template_chip, 'The task learning outcome feedback template should be copied'
    assert_equal copied_group_chip, copied_template_chip.parent_chip
    assert_equal template_chip_td_lo.description, copied_template_chip.description
    assert_equal template_chip_td_lo.task_status, copied_template_chip.task_status
    assert_equal template_chip_td_lo.summary_text, copied_template_chip.summary_text
    assert_equal template_chip_td_lo.comment_text, copied_template_chip.comment_text

    new_link = LearningOutcomeLink.find_by(source_id: new_lo1.id, target_id: global_learning_outcome.id)
    assert_not_nil new_link, 'New learning outcome 1 should be linked to the global learning outcome'

    new_link = LearningOutcomeLink.find_by(source_id: new_td_lo.id, target_id: new_lo2.id)
    assert_not_nil new_link, 'New learning outcome 2 should be linked to the task definition learning outcome'
  end

end
