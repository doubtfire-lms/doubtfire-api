require 'test_helper'
require 'minitest/mock'

class CommunicationSetTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

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

    # In isolation both rules match everyone; subtracting the first reproduces the cascade.
    first_independent = communication_set.independent_matches_for_rule(first_rule)
    second_independent = communication_set.independent_matches_for_rule(second_rule)

    assert_equal 2, first_independent.length
    assert_equal 2, second_independent.length
    assert_empty second_independent - first_independent
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

  def test_login_status_condition_uses_relative_sign_in_time_and_handles_never
    travel_to Time.zone.parse('2026-07-22 12:00:00 UTC') do
      unit, rule = unit_and_rule('Login activity')
      old_project = activity_project(unit, last_sign_in_at: 8.days.ago, last_viewed_at: 1.day.ago)
      recent_project = activity_project(unit, last_sign_in_at: 6.days.ago, last_viewed_at: 10.days.ago)
      boundary_project = activity_project(unit, last_sign_in_at: 7.days.ago)
      never_project = activity_project(unit)
      condition = rule.communication_conditions.create!(
        type: 'LoginStatusCondition',
        operator: 'more_than',
        activity_days: 7
      )

      assert_equal [old_project.id, never_project.id].sort, rule.matching_projects.map(&:id).sort

      condition.update!(operator: 'within_last')
      assert_equal [recent_project.id, boundary_project.id].sort, rule.matching_projects.map(&:id).sort
    end
  end

  def test_unit_viewed_status_condition_uses_project_view_time_and_handles_never
    travel_to Time.zone.parse('2026-07-22 12:00:00 UTC') do
      unit, rule = unit_and_rule('Unit activity')
      old_project = activity_project(unit, last_sign_in_at: 1.day.ago, last_viewed_at: 8.days.ago)
      recent_project = activity_project(unit, last_sign_in_at: 10.days.ago, last_viewed_at: 6.days.ago)
      boundary_project = activity_project(unit, last_viewed_at: 7.days.ago)
      never_project = activity_project(unit, last_sign_in_at: 1.day.ago)
      condition = rule.communication_conditions.create!(
        type: 'UnitViewedStatusCondition',
        operator: 'more_than',
        activity_days: 7
      )

      assert_equal [old_project.id, never_project.id].sort, rule.matching_projects.map(&:id).sort

      condition.update!(operator: 'within_last')
      assert_equal [recent_project.id, boundary_project.id].sort, rule.matching_projects.map(&:id).sort
    end
  end

  def test_portfolio_submitted_condition_matches_both_submission_states
    unit, rule = unit_and_rule('Portfolio submission')
    submitted_project = FactoryBot.create(
      :project,
      unit: unit,
      portfolio_submission_date: nil
    )
    unsubmitted_project = FactoryBot.create(
      :project,
      unit: unit,
      portfolio_submission_date: Time.zone.parse('2026-07-22 12:00:00 UTC')
    )
    condition = rule.communication_conditions.create!(
      type: 'PortfolioSubmittedCondition',
      operator: 'equal_to',
      submitted_portfolio: true
    )

    submitted_project.stub(:portfolio_exists?, true) do
      unsubmitted_project.stub(:portfolio_exists?, false) do
        projects = [submitted_project, unsubmitted_project]
        assert_equal [submitted_project.id], rule.matching_projects(projects).map(&:id)

        condition.update!(submitted_portfolio: false)
        assert_equal [unsubmitted_project.id], rule.matching_projects(projects).map(&:id)
      end
    end
  end

  def test_copy_to_preserves_relative_activity_conditions
    source_unit, rule = unit_and_rule('Reusable activity')
    destination_unit = FactoryBot.create(:unit, with_students: false, task_count: 0, tutorials: 0, outcome_count: 0, staff_count: 0)
    rule.communication_conditions.create!(
      type: 'LoginStatusCondition',
      operator: 'within_last',
      activity_days: 3
    )
    rule.communication_conditions.create!(
      type: 'UnitViewedStatusCondition',
      operator: 'more_than',
      activity_days: 14
    )

    copied_set = source_unit.communication_sets.first.copy_to(destination_unit)
    copied_conditions = copied_set.communication_rules.first.communication_conditions.index_by(&:type)

    assert_equal 3, copied_conditions.fetch('LoginStatusCondition').activity_days
    assert_equal 'within_last', copied_conditions.fetch('LoginStatusCondition').operator
    assert_equal 14, copied_conditions.fetch('UnitViewedStatusCondition').activity_days
    assert_equal 'more_than', copied_conditions.fetch('UnitViewedStatusCondition').operator
  end

  def test_group_set_enrolment_condition_matches_students_in_any_group_of_the_set
    unit, rule = unit_with_groups
    marked_set = unit.group_sets.first
    other_set = FactoryBot.create(:group_set, unit: unit)
    tutorial = unit.tutorials.first

    in_first_group = join_group(unit, FactoryBot.create(:group, group_set: marked_set, tutorial: tutorial))
    in_second_group = join_group(unit, FactoryBot.create(:group, group_set: marked_set, tutorial: tutorial))
    in_other_set = join_group(unit, FactoryBot.create(:group, group_set: other_set, tutorial: tutorial))
    ungrouped = FactoryBot.create(:project, unit: unit)

    rule.communication_conditions.create!(
      type: 'GroupSetEnrolmentCondition',
      operator: 'enrolled_in',
      group_set: marked_set
    )

    matches = rule.communication_set.independent_matches_for_rule(rule)

    assert_equal [in_first_group.id, in_second_group.id].sort, matches.map(&:id).sort
    assert_not_includes matches.map(&:id), in_other_set.id
    assert_not_includes matches.map(&:id), ungrouped.id
  end

  def test_group_set_enrolment_condition_can_select_students_outside_the_set
    unit, rule = unit_with_groups
    group_set = unit.group_sets.first
    grouped = join_group(unit, FactoryBot.create(:group, group_set: group_set, tutorial: unit.tutorials.first))
    ungrouped = FactoryBot.create(:project, unit: unit)

    rule.communication_conditions.create!(
      type: 'GroupSetEnrolmentCondition',
      operator: 'not_enrolled_in',
      group_set: group_set
    )

    matches = rule.communication_set.independent_matches_for_rule(rule)

    assert_equal [ungrouped.id], matches.map(&:id)
    assert_not_includes matches.map(&:id), grouped.id
  end

  def test_group_enrolment_condition_matches_only_the_named_group
    unit, rule = unit_with_groups
    group_set = unit.group_sets.first
    tutorial = unit.tutorials.first
    wanted_group = FactoryBot.create(:group, group_set: group_set, tutorial: tutorial)
    other_group = FactoryBot.create(:group, group_set: group_set, tutorial: tutorial)

    member = join_group(unit, wanted_group)
    other_member = join_group(unit, other_group)

    rule.communication_conditions.create!(
      type: 'GroupEnrolmentCondition',
      operator: 'enrolled_in',
      group: wanted_group
    )

    matches = rule.communication_set.independent_matches_for_rule(rule)

    assert_equal [member.id], matches.map(&:id)
    assert_not_includes matches.map(&:id), other_member.id
  end

  def test_group_conditions_ignore_memberships_a_student_has_left
    unit, rule = unit_with_groups
    group_set = unit.group_sets.first
    group = FactoryBot.create(:group, group_set: group_set, tutorial: unit.tutorials.first)
    departed = join_group(unit, group)
    departed.group_memberships.first.update!(active: false)

    rule.communication_conditions.create!(
      type: 'GroupSetEnrolmentCondition',
      operator: 'enrolled_in',
      group_set: group_set
    )

    assert_empty rule.communication_set.independent_matches_for_rule(rule)
  end

  def test_copy_to_repoints_group_conditions_by_name
    unit, rule = unit_with_groups
    group_set = unit.group_sets.first
    group = FactoryBot.create(:group, group_set: group_set, tutorial: unit.tutorials.first)

    rule.communication_conditions.create!(
      type: 'GroupSetEnrolmentCondition',
      operator: 'enrolled_in',
      group_set: group_set
    )
    rule.communication_conditions.create!(
      type: 'GroupEnrolmentCondition',
      operator: 'enrolled_in',
      group: group
    )

    destination_unit = FactoryBot.create(:unit, with_students: false, task_count: 0, tutorials: 1, outcome_count: 0, staff_count: 0)
    destination_set = FactoryBot.create(:group_set, unit: destination_unit, name: group_set.name)
    destination_group = FactoryBot.create(:group, group_set: destination_set, name: group.name, tutorial: destination_unit.tutorials.first)

    copied = rule.communication_set.copy_to(destination_unit)
    conditions = copied.communication_rules.first.communication_conditions.index_by(&:type)

    assert_equal destination_set.id, conditions.fetch('GroupSetEnrolmentCondition').group_set_id
    assert_equal destination_group.id, conditions.fetch('GroupEnrolmentCondition').group_id
    assert_predicate copied, :executable?
  end

  def test_copy_to_leaves_group_conditions_unresolved_when_the_set_is_missing
    unit, rule = unit_with_groups
    group_set = unit.group_sets.first

    rule.communication_conditions.create!(
      type: 'GroupSetEnrolmentCondition',
      operator: 'enrolled_in',
      group_set: group_set
    )

    destination_unit = FactoryBot.create(:unit, with_students: false, task_count: 0, tutorials: 1, outcome_count: 0, staff_count: 0)
    copied = rule.communication_set.copy_to(destination_unit)

    assert_nil copied.communication_rules.first.communication_conditions.first.group_set_id
    assert_not copied.executable?
  end

  private

  def unit_with_groups
    unit = FactoryBot.create(
      :unit,
      with_students: false,
      task_count: 0,
      stream_count: 0,
      tutorials: 1,
      outcome_count: 0,
      staff_count: 0,
      group_sets: 1
    )
    set = unit.communication_sets.create!(name: 'Group nudges', active: true)
    rule = set.communication_rules.create!(name: 'Group nudges', operator: 'and', position: 0)

    [unit, rule]
  end

  def join_group(unit, group)
    project = FactoryBot.create(:project, unit: unit)
    group.group_memberships.create!(project: project, active: true)

    project
  end

  def unit_and_rule(name)
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
    communication_set = unit.communication_sets.create!(name: name, active: true)
    rule = communication_set.communication_rules.create!(name: name, operator: 'and', position: 0)

    [unit, rule]
  end

  def activity_project(unit, last_sign_in_at: nil, last_viewed_at: nil)
    user = FactoryBot.create(:user, :student, last_sign_in_at: last_sign_in_at)
    FactoryBot.create(:project, unit: unit, user: user, last_viewed_at: last_viewed_at)
  end
end
