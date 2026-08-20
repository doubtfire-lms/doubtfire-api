require 'test_helper'

class CommunicationTransferTest < ActiveSupport::TestCase
  def setup
    @source_unit = unit_with_task('T1.1')
    @set = set_with_task_rule(@source_unit)
    @rule = @set.communication_rules.first
  end

  def test_exported_document_carries_abbreviations_rather_than_ids
    document = CommunicationTransfer.export_set(@set)
    condition = document.dig('set', 'rules', 0, 'conditions', 0)

    assert_equal CommunicationTransfer::SET_FORMAT, document['format']
    assert_equal 'T1.1', condition.dig('reference', 'task_definition')
    assert_not condition.key?('task_definition_id')
    assert_not condition.key?('id')
  end

  def test_importing_into_a_unit_with_the_same_task_repoints_the_reference
    target_unit = unit_with_task('T1.1')

    imported = CommunicationTransfer.import_set(CommunicationTransfer.export_set(@set), target_unit)
    condition = imported.communication_rules.first.communication_conditions.first

    assert_equal target_unit.task_definitions.find_by(abbreviation: 'T1.1').id, condition.task_definition_id
    assert_not condition.unresolved?
    assert_predicate imported, :executable?
  end

  def test_importing_without_the_task_keeps_the_rule_but_blocks_the_set
    target_unit = unit_with_task('Different')

    imported = CommunicationTransfer.import_set(CommunicationTransfer.export_set(@set), target_unit)
    rule = imported.communication_rules.first

    # The point of the copy: the conditions and actions survive the move.
    assert_equal 1, rule.communication_conditions.count
    assert_equal 1, rule.communication_actions.count
    assert_nil rule.communication_conditions.first.task_definition_id

    assert_predicate rule, :unresolved?
    assert_not imported.executable?
    assert_empty rule.matching_projects
  end

  def test_a_condition_pointing_at_another_units_task_is_unresolved
    other_unit = unit_with_task('T1.1')
    condition = @rule.communication_conditions.first
    condition.update_column(:task_definition_id, other_unit.task_definitions.first.id)

    assert_predicate condition.reload, :unresolved?
    assert_not @set.executable?
  end

  def test_a_condition_whose_task_was_deleted_is_unresolved
    condition = @rule.communication_conditions.first
    condition.update_column(:task_definition_id, nil)

    assert_predicate condition.reload, :unresolved?
    assert_not @set.executable?
  end

  def test_importing_a_single_rule_appends_it_to_an_existing_set
    target_unit = unit_with_task('T1.1')
    target_set = target_unit.communication_sets.create!(name: 'Existing', active: true)
    target_set.communication_rules.create!(name: 'Already here', operator: 'and', position: 0)

    CommunicationTransfer.import_rule(CommunicationTransfer.export_rule(@rule), target_set)

    assert_equal ['Already here', 'Chase T1.1'], target_set.reload.communication_rules.map(&:name)
    assert_equal [0, 1], target_set.communication_rules.map(&:position)
  end

  def test_a_document_of_the_wrong_kind_is_rejected
    target_unit = unit_with_task('T1.1')
    target_set = target_unit.communication_sets.create!(name: 'Existing', active: true)

    assert_raises(CommunicationTransfer::InvalidDocument) do
      CommunicationTransfer.import_rule(CommunicationTransfer.export_set(@set), target_set)
    end

    assert_raises(CommunicationTransfer::InvalidDocument) do
      CommunicationTransfer.import_set({ 'format' => 'something else' }, target_unit)
    end
  end

  def test_importing_into_the_source_unit_duplicates_the_set_under_a_free_name
    imported = CommunicationTransfer.import_set(CommunicationTransfer.export_set(@set), @source_unit)

    assert_equal 'Nudges (2)', imported.name
    assert_predicate imported, :executable?
  end

  def test_imported_schedules_arrive_switched_off
    @set.communication_set_schedules.create!(name: 'Weekly', active: true, anchor_week: 3, anchor_day: 'Monday')
    target_unit = unit_with_task('T1.1')

    schedule = CommunicationTransfer.import_set(
      CommunicationTransfer.export_set(@set), target_unit
    ).communication_set_schedules.first

    assert_equal 'Weekly', schedule.name
    assert_equal 3, schedule.anchor_week
    assert_not schedule.active
    assert_nil schedule.next_run_at
  end

  def test_a_set_rolled_over_without_matching_tasks_keeps_its_rules
    target_unit = unit_with_task('Different')

    rolled_over = @set.copy_to(target_unit)

    assert_equal 1, rolled_over.communication_rules.first.communication_conditions.count
    assert_not rolled_over.executable?
  end

  private

  def unit_with_task(abbreviation)
    unit = FactoryBot.create(
      :unit,
      with_students: false,
      task_count: 0,
      stream_count: 0,
      tutorials: 0,
      outcome_count: 0,
      staff_count: 1,
      campus_count: 1
    )

    unit.task_definitions.create!(
      name: "Task #{abbreviation}",
      abbreviation: abbreviation,
      description: 'Test task',
      weighting: 1,
      target_grade: 0,
      start_date: unit.start_date,
      target_date: unit.start_date + 1.week,
      upload_requirements: []
    )

    unit.reload
  end

  def set_with_task_rule(unit)
    set = unit.communication_sets.create!(name: 'Nudges', active: true)
    rule = set.communication_rules.create!(name: 'Chase T1.1', operator: 'and', position: 0)

    rule.communication_conditions.create!(
      type: 'TaskDefinitionStatusCondition',
      operator: 'equal_to',
      task_definition: unit.task_definitions.first,
      task_statuses: ['not_started']
    )

    rule.communication_actions.create!(
      type: 'EmailStudentAction',
      subject: 'Get started',
      body: 'Hi {{student.first_name}}'
    )

    set
  end
end
