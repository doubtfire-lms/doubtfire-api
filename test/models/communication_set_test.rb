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

  private

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
