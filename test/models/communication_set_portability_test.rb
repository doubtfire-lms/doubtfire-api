require 'test_helper'

class CommunicationSetPortabilityTest < ActiveSupport::TestCase
  def setup
    @source_unit = build_unit(task_abbreviations: ['T1.1'])
    @communication_set = @source_unit.communication_sets.create!(name: 'Nudge Set', active: true)

    @rule = @communication_set.communication_rules.create!(
      name: 'Chase unstarted tasks',
      operator: 'and',
      position: 0
    )

    @rule.communication_conditions.create!(
      type: 'TaskDefinitionStatusCondition',
      operator: 'equal_to',
      task_definition: @source_unit.task_definitions.first,
      task_statuses: ['not_started']
    )

    @rule.communication_actions.create!(
      type: 'EmailStudentAction',
      subject: 'Get started on {{unit.code}}',
      body: 'Hi {{student.first_name}}'
    )
  end

  def test_exported_document_carries_natural_keys_rather_than_ids
    document = CommunicationSetExporter.export_set(@communication_set)

    assert_equal CommunicationSetExporter::SET_FORMAT, document['format']
    assert_equal @source_unit.code, document.dig('source', 'unit_code')

    condition = document.dig('set', 'rules', 0, 'conditions', 0)

    assert_equal 'TaskDefinitionStatusCondition', condition['type']
    assert_equal 'T1.1', condition.dig('references', 'task_definition', 'abbreviation')
    assert_not condition.key?('task_definition_id')
    assert_not condition.key?('id')
  end

  def test_importing_into_a_unit_with_matching_tasks_repoints_the_reference
    target_unit = build_unit(task_abbreviations: ['T1.1'])
    document = CommunicationSetExporter.export_set(@communication_set)

    report = CommunicationSetImporter.new(document, target_unit).import_set

    assert_equal 0, report[:unresolved_count]

    imported = target_unit.communication_sets.find(report[:imported_id])
    condition = imported.communication_rules.first.communication_conditions.first

    assert_equal target_unit.task_definitions.find_by(abbreviation: 'T1.1').id, condition.task_definition_id
    assert_not condition.unresolved?
    assert_predicate imported, :executable?
  end

  def test_importing_into_a_unit_without_the_task_keeps_a_placeholder_and_blocks_execution
    target_unit = build_unit(task_abbreviations: ['Different'])
    document = CommunicationSetExporter.export_set(@communication_set)

    report = CommunicationSetImporter.new(document, target_unit).import_set

    assert_equal 1, report[:unresolved_count]
    assert_equal 'task_definition', report[:unresolved].first[:reference]
    assert_equal 'T1.1', report[:unresolved].first.dig(:descriptor, 'abbreviation')

    imported = target_unit.communication_sets.find(report[:imported_id])
    condition = imported.communication_rules.first.communication_conditions.first

    assert_nil condition.task_definition_id
    assert_predicate condition, :unresolved?
    assert_equal 'T1.1', condition.unresolved_references.dig('task_definition', 'abbreviation')

    assert_not imported.executable?
    assert_equal ['Chase unstarted tasks'], imported.unresolved_rules.map(&:name)

    # The rule must refuse to evaluate rather than treating the missing task as
    # 'not_started' and matching the whole unit.
    assert_raises(CommunicationRule::UnresolvedReferenceError) do
      imported.communication_rules.first.matching_projects
    end
  end

  def test_a_dry_run_reports_without_persisting
    target_unit = build_unit(task_abbreviations: ['Different'])
    document = CommunicationSetExporter.export_set(@communication_set)

    report = CommunicationSetImporter.new(document, target_unit).import_set(dry_run: true)

    assert_equal 1, report[:unresolved_count]
    assert_nil report[:imported_id]
    assert_equal 0, target_unit.communication_sets.count
  end

  def test_importing_a_single_rule_appends_it_to_an_existing_set
    target_unit = build_unit(task_abbreviations: ['T1.1'])
    target_set = target_unit.communication_sets.create!(name: 'Existing', active: true)
    target_set.communication_rules.create!(name: 'Already here', operator: 'and', position: 0)

    document = CommunicationSetExporter.export_rule(@rule)
    report = CommunicationSetImporter.new(document, target_unit).import_rule(target_set)

    assert_equal 0, report[:unresolved_count]
    assert_equal ['Already here', 'Chase unstarted tasks'], target_set.reload.communication_rules.map(&:name)
    assert_equal [0, 1], target_set.communication_rules.map(&:position)
  end

  def test_importing_a_set_document_as_a_rule_is_rejected
    target_unit = build_unit(task_abbreviations: ['T1.1'])
    target_set = target_unit.communication_sets.create!(name: 'Existing', active: true)
    document = CommunicationSetExporter.export_set(@communication_set)

    assert_raises(CommunicationSetImporter::InvalidDocument) do
      CommunicationSetImporter.new(document, target_unit).import_rule(target_set)
    end
  end

  def test_importing_into_the_source_unit_duplicates_the_set_under_a_free_name
    document = CommunicationSetExporter.export_set(@communication_set)

    report = CommunicationSetImporter.new(document, @source_unit).import_set

    assert_equal 'Nudge Set (2)', report[:imported_name]
    assert_equal 0, report[:unresolved_count]
  end

  def test_imported_schedules_arrive_switched_off
    @communication_set.communication_set_schedules.create!(
      name: 'Weekly nudge',
      active: true,
      anchor_week: 3,
      anchor_day: 'Monday'
    )

    target_unit = build_unit(task_abbreviations: ['T1.1'])
    document = CommunicationSetExporter.export_set(@communication_set)
    report = CommunicationSetImporter.new(document, target_unit).import_set

    schedule = target_unit.communication_sets.find(report[:imported_id]).communication_set_schedules.first

    assert_equal 'Weekly nudge', schedule.name
    assert_equal 3, schedule.anchor_week
    assert_not schedule.active
    assert_nil schedule.next_run_at
  end

  def test_a_condition_whose_task_was_deleted_is_unresolved_without_a_placeholder
    condition = @rule.communication_conditions.first
    condition.update_column(:task_definition_id, nil)

    assert_predicate condition.reload, :unresolved?
    assert_not condition.unresolved_reference?
    assert_not @communication_set.executable?
  end

  private

  def build_unit(task_abbreviations:)
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

    task_abbreviations.each_with_index do |abbreviation, index|
      unit.task_definitions.create!(
        name: "Task #{abbreviation}",
        abbreviation: abbreviation,
        description: 'Test task',
        weighting: 1,
        target_grade: 0,
        start_date: unit.start_date + index.weeks,
        target_date: unit.start_date + (index + 1).weeks,
        upload_requirements: []
      )
    end

    unit.reload
  end
end
