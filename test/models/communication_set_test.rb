require 'test_helper'

class CommunicationSetTest < ActiveSupport::TestCase
  def test_preview_projects_for_rule_excludes_students_claimed_by_earlier_rules
    unit = FactoryBot.create(
      :unit,
      student_count: 2,
      unenrolled_student_count: 0,
      part_enrolled_student_count: 0,
      inactive_student_count: 0,
      task_count: 1,
      stream_count: 0,
      tutorials: 0
    )
    communication_set = unit.communication_sets.create!(name: 'Test Set', active: true)

    first_rule = communication_set.communication_rules.create!(name: 'First Rule', operator: 'and', position: 0)
    second_rule = communication_set.communication_rules.create!(name: 'Second Rule', operator: 'and', position: 1)

    first_rule.communication_conditions.create!(
      type: 'TaskDefinitionStatusCondition',
      operator: 'equal_to',
      task_definition: unit.task_definitions.first,
      task_statuses: ['not_started']
    )

    second_rule.communication_conditions.create!(
      type: 'TaskDefinitionStatusCondition',
      operator: 'equal_to',
      task_definition: unit.task_definitions.first,
      task_statuses: ['not_started']
    )

    first_rule_matches = communication_set.preview_projects_for_rule(first_rule)
    second_rule_matches = communication_set.preview_projects_for_rule(second_rule)

    assert_equal 2, first_rule_matches.length
    assert_empty second_rule_matches
  end

  def test_preview_projects_for_rule_matches_spec_con_days
    unit = FactoryBot.create(
      :unit,
      with_students: false,
      task_count: 0,
      stream_count: 0,
      tutorials: 0,
      outcome_count: 0,
      staff_count: 0,
      campus_count: 1
    )

    matching_project = FactoryBot.create(:project, unit: unit, spec_con_days: 4)
    FactoryBot.create(:project, unit: unit, spec_con_days: 1)

    communication_set = unit.communication_sets.create!(name: 'Test Set', active: true)
    communication_rule = communication_set.communication_rules.create!(name: 'Spec Con Rule', operator: 'and', position: 0)

    communication_rule.communication_conditions.create!(
      type: 'SpecConCondition',
      operator: 'greater_than_or_equal_to',
      spec_con_days: 3
    )

    matched_projects = communication_set.preview_projects_for_rule(communication_rule)

    assert_equal [matching_project.id], matched_projects.map(&:id)
  end
end
