require 'test_helper'

class CommunicationConditionTest < ActiveSupport::TestCase
  def test_task_definition_status_condition_accepts_multiple_task_statuses
    unit = FactoryBot.create(:unit, with_students: false, task_count: 1, stream_count: 0, tutorials: 0)
    communication_set = unit.communication_sets.create!(name: 'Test Set', active: true)
    communication_rule = communication_set.communication_rules.create!(name: 'Test Rule', operator: 'and', position: 0)

    condition = TaskDefinitionStatusCondition.new(
      communication: communication_rule,
      operator: 'equal_to',
      task_definition: unit.task_definitions.first,
      task_statuses: %w[not_started working_on_it fix_and_resubmit]
    )

    assert condition.valid?, condition.errors.full_messages
    condition.save!

    condition.reload
    assert_equal %w[not_started working_on_it fix_and_resubmit], condition.task_statuses
  end

  def test_spec_con_condition_accepts_integer_spec_con_days
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0, tutorials: 0, outcome_count: 0, staff_count: 0)
    communication_set = unit.communication_sets.create!(name: 'Test Set', active: true)
    communication_rule = communication_set.communication_rules.create!(name: 'Test Rule', operator: 'and', position: 0)

    condition = SpecConCondition.new(
      communication: communication_rule,
      operator: 'greater_than_or_equal_to',
      spec_con_days: 4
    )

    assert condition.valid?, condition.errors.full_messages
    condition.save!

    condition.reload
    assert_equal 4, condition.spec_con_days
  end

  def test_activity_conditions_require_supported_operator_and_positive_integer_days
    rule = communication_rule

    %w[LoginStatusCondition UnitViewedStatusCondition].each do |type|
      condition = CommunicationCondition.new(
        type: type,
        communication: rule,
        operator: 'more_than',
        activity_days: 7
      )

      assert condition.valid?, condition.errors.full_messages

      condition.activity_days = 0
      assert_not condition.valid?

      condition.activity_days = 1.5
      assert_not condition.valid?

      condition.activity_days = 7
      condition.operator = 'before'
      assert_not condition.valid?
    end
  end

  def test_portfolio_submitted_condition_requires_a_boolean
    condition = CommunicationCondition.new(
      type: 'PortfolioSubmittedCondition',
      communication: communication_rule,
      operator: 'equal_to',
      submitted_portfolio: false
    )

    assert condition.valid?, condition.errors.full_messages

    condition.submitted_portfolio = nil
    assert_not condition.valid?
  end

  def test_group_enrolment_condition_follows_the_group_set_of_its_group
    rule = communication_rule
    group_set = FactoryBot.create(:group_set, unit: rule.unit)
    group = FactoryBot.create(:group, group_set: group_set, tutorial: rule.unit.tutorials.first)

    condition = GroupEnrolmentCondition.create!(
      communication: rule,
      operator: 'enrolled_in',
      group: group,
      group_set: FactoryBot.create(:group_set, unit: rule.unit)
    )

    assert_equal group_set.id, condition.group_set_id
    assert_not condition.unresolved?
  end

  def test_group_conditions_pointing_at_another_unit_are_unresolved
    rule = communication_rule
    other_unit = FactoryBot.create(:unit, with_students: false, task_count: 0, tutorials: 1, outcome_count: 0, staff_count: 0)
    other_group_set = FactoryBot.create(:group_set, unit: other_unit)
    other_group = FactoryBot.create(:group, group_set: other_group_set, tutorial: other_unit.tutorials.first)

    group_set_condition = GroupSetEnrolmentCondition.create!(
      communication: rule,
      operator: 'enrolled_in',
      group_set: other_group_set
    )
    group_condition = GroupEnrolmentCondition.create!(
      communication: rule,
      operator: 'enrolled_in',
      group: other_group
    )

    assert_predicate group_set_condition, :unresolved?
    assert_predicate group_condition, :unresolved?
  end

  def test_group_conditions_only_accept_enrolment_operators
    rule = communication_rule
    group_set = FactoryBot.create(:group_set, unit: rule.unit)

    condition = GroupSetEnrolmentCondition.new(
      communication: rule,
      operator: 'not_enrolled_in',
      group_set: group_set
    )

    assert condition.valid?, condition.errors.full_messages

    condition.operator = 'equal_to'
    assert_not condition.valid?
  end

  private

  def communication_rule
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0, tutorials: 1, outcome_count: 0, staff_count: 0)
    communication_set = unit.communication_sets.create!(name: 'Test Set', active: true)
    communication_set.communication_rules.create!(name: 'Test Rule', operator: 'and', position: 0)
  end
end
