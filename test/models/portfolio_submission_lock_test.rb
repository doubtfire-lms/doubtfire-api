# frozen_string_literal: true

require 'test_helper'

class PortfolioSubmissionLockTest < ActiveSupport::TestCase
  def build_unit(**attributes)
    FactoryBot.create(
      :unit,
      { with_students: false, task_count: 0, tutorials: 0, outcome_count: 0,
        staff_count: 0, campus_count: 0 }.merge(attributes)
    )
  end

  def test_portfolio_lock_defaults_to_off
    unit = build_unit

    assert_not unit.lock_project_on_portfolio_submission?
  end

  def test_lock_is_immediate_retroactive_and_clears_after_compile_failure
    unit = build_unit(lock_project_on_portfolio_submission: false)
    project = FactoryBot.create(:project, unit: unit, compile_portfolio: true)

    assert_not project.portfolio_locked?

    unit.update!(lock_project_on_portfolio_submission: true)
    assert project.reload.portfolio_locked?

    project.update!(compile_portfolio: false)
    assert_not project.reload.portfolio_locked?
  end

  def test_locked_project_rejects_task_and_comment_changes_and_destruction
    unit = build_unit(lock_project_on_portfolio_submission: true)
    definition = FactoryBot.create(:task_definition, unit: unit)
    project = FactoryBot.create(:project, unit: unit)
    task = FactoryBot.create(:task, project: project, task_definition: definition)
    comment = TaskComment.create!(
      task: task,
      user: project.student,
      recipient: project.student,
      comment: 'Submitted evidence'
    )

    project.update!(compile_portfolio: true)

    task.task_status = TaskStatus.ready_for_feedback
    assert_not task.save
    assert_includes task.errors[:base], 'Task cannot be changed while the project portfolio is submitted'

    comment.comment = 'Changed evidence'
    assert_not comment.save
    assert_not comment.destroy
    assert Task.exists?(task.id)
    assert TaskComment.exists?(comment.id)
    assert_not task.destroy
    assert Task.exists?(task.id)

    assert_not definition.destroy
    assert TaskDefinition.exists?(definition.id)
    assert Task.exists?(task.id)
  end

  def test_group_submission_skips_a_member_whose_portfolio_is_locked
    unit = FactoryBot.create(
      :unit,
      lock_project_on_portfolio_submission: true,
      student_count: 2,
      unenrolled_student_count: 0,
      part_enrolled_student_count: 0,
      inactive_student_count: 0,
      task_count: 1,
      group_sets: 1,
      groups: [{ gs: 0, students: 2 }],
      group_tasks: [{ idx: 0, gs: 0 }]
    )
    group = unit.groups.first
    submitter_project, frozen_project = group.projects.to_a
    submitter_task = submitter_project.task_for_task_definition(unit.task_definitions.first)
    frozen_task = frozen_project.task_for_task_definition(unit.task_definitions.first)
    frozen_task_status_id = frozen_task.task_status_id
    frozen_project.update!(compile_portfolio: true)
    contributions = group.projects.map { |project| { project: project, pct: 50, pts: 3 } }

    group.create_submission(submitter_task, 'Group submission', contributions)

    assert_nil frozen_task.reload.group_submission
    assert_equal frozen_task_status_id, frozen_task.task_status_id
    assert frozen_project.reload.portfolio_locked?
  end
end
