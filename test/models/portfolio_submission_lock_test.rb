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

  def test_portfolio_settings_default_to_existing_unlocked_behaviour
    unit = build_unit

    assert_nil unit.portfolio_deadline
    assert unit.portfolio_deadline_per_campus?
    assert_not unit.lock_project_on_portfolio_submission?
  end

  def test_shared_deadline_requires_a_campus
    unit = build_unit
    unit.portfolio_deadline = '2026-10-04T23:30'
    unit.portfolio_deadline_per_campus = false

    assert_not unit.valid?
    assert_includes unit.errors[:portfolio_deadline_campus],
                    'must be selected when one campus timezone is used for all students'

    unit.portfolio_deadline_campus = FactoryBot.create(:campus, timezone: 'Australia/Perth')
    assert unit.valid?, unit.errors.full_messages.to_sentence
  end

  def test_deadline_rejects_an_invalid_local_datetime
    unit = build_unit

    unit.portfolio_deadline = '17 August 2026 at five'

    assert_not unit.valid?
    assert_includes unit.errors[:portfolio_deadline], 'must use the format YYYY-MM-DDTHH:mm'
  end

  def test_effective_deadline_uses_project_campus_and_special_consideration_calendar_days
    campus = FactoryBot.create(:campus, timezone: 'Australia/Melbourne')
    unit = build_unit(
      portfolio_deadline: '2026-10-03T23:30',
      portfolio_deadline_per_campus: true
    )
    project = FactoryBot.create(:project, unit: unit, campus: campus, spec_con_days: 2)

    deadline = project.effective_portfolio_deadline

    assert_equal 'Australia/Melbourne', project.effective_portfolio_deadline_timezone
    assert_equal '2026-10-05T23:30:00+11:00', deadline.iso8601
    assert_not project.portfolio_deadline_passed?(at: deadline)
    assert project.portfolio_deadline_passed?(at: deadline + 1.second)
  end

  def test_shared_deadline_uses_selected_campus_even_when_it_is_inactive
    project_campus = FactoryBot.create(:campus, timezone: 'Australia/Melbourne')
    deadline_campus = FactoryBot.create(:campus, timezone: 'Australia/Perth', active: false)
    unit = build_unit(
      portfolio_deadline: '2026-08-17T16:00',
      portfolio_deadline_per_campus: false,
      portfolio_deadline_campus: deadline_campus
    )
    project = FactoryBot.create(:project, unit: unit, campus: project_campus)

    assert_equal 'Australia/Perth', project.effective_portfolio_deadline_timezone
    assert_equal '2026-08-17T16:00:00+08:00', project.effective_portfolio_deadline.iso8601
  end

  def test_deadline_without_a_project_campus_uses_the_deployment_timezone
    unit = build_unit(
      portfolio_deadline: '2026-08-17T16:00',
      portfolio_deadline_per_campus: true
    )
    project = FactoryBot.create(:project, unit: unit, campus: nil)

    deadline = project.effective_portfolio_deadline

    assert_equal Time.zone.name, project.effective_portfolio_deadline_timezone
    assert_equal [2026, 8, 17, 16, 0],
                 [deadline.year, deadline.month, deadline.day, deadline.hour, deadline.min]
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

  def test_group_operations_can_use_the_explicit_bypass
    unit = build_unit(lock_project_on_portfolio_submission: true)
    definition = FactoryBot.create(:task_definition, unit: unit)
    project = FactoryBot.create(:project, unit: unit, compile_portfolio: true)
    task = FactoryBot.build(:task, project: project, task_definition: definition)

    assert_not task.save

    task.portfolio_lock_bypass = true
    assert task.save, task.errors.full_messages.to_sentence
  end

  def test_group_submission_updates_a_frozen_member_transactionally
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
    frozen_project.update!(compile_portfolio: true)
    contributions = group.projects.map { |project| { project: project, pct: 50, pts: 3 } }

    submission = group.create_submission(submitter_task, 'Group submission', contributions)

    assert_equal submission, frozen_task.reload.group_submission
    assert_equal 50, frozen_task.contribution_pct
    assert frozen_project.reload.portfolio_locked?
  end

  def test_lock_authorisation_applies_to_students_tutors_and_convenors_but_not_portfolio_assessment
    unit = build_unit(lock_project_on_portfolio_submission: true)
    definition = FactoryBot.create(:task_definition, unit: unit)
    project = FactoryBot.create(:project, unit: unit)
    task = FactoryBot.create(:task, project: project, task_definition: definition)
    tutor = FactoryBot.create(:user, :tutor)
    convenor = FactoryBot.create(:user, :convenor)
    unit.employ_staff(tutor, Role.tutor)
    unit.employ_staff(convenor, Role.convenor)
    project.update!(compile_portfolio: true)

    assert_not AuthorisationHelpers.authorise?(project.student, task, :make_submission)
    assert_not AuthorisationHelpers.authorise?(tutor, task, :make_submission)
    assert_not AuthorisationHelpers.authorise?(convenor, task, :make_submission)
    assert_not AuthorisationHelpers.authorise?(project.student, project, :change)
    assert AuthorisationHelpers.authorise?(convenor, project, :assess)
  end
end
