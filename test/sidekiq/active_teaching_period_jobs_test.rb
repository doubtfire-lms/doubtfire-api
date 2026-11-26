require 'test_helper'

class ActiveTeachingPeriodJobsTest < ActiveSupport::TestCase
  def test_within_teaching_dates_scope_matches_within_teaching_dates
    now = Time.zone.now
    running_period = FactoryBot.create(:teaching_period, start_date: now - 10.weeks, end_date: now + 1.week, active_until: now + 3.weeks)
    marking_period = FactoryBot.create(:teaching_period, start_date: now - 14.weeks, end_date: now - 1.week, active_until: now + 1.week)

    units = [
      running = create_unit(teaching_period: running_period),
      in_marking_window = create_unit(teaching_period: marking_period),
      no_period = create_unit,
      ends_today = create_unit(start_date: now - 20.weeks, end_date: now.beginning_of_day),
      ended_yesterday = create_unit(start_date: now - 20.weeks, end_date: now.beginning_of_day - 1.day),
      flag_off = create_unit(active: false)
    ]

    scoped_ids = Unit.within_teaching_dates.where(id: units.map(&:id)).pluck(:id)

    assert_equal units.select(&:within_teaching_dates?).map(&:id).sort, scoped_ids.sort
    assert_equal [running.id, no_period.id, ends_today.id].sort, scoped_ids.sort
    assert_not_includes scoped_ids, in_marking_window.id
    assert_not_includes scoped_ids, ended_yesterday.id
    assert_not_includes scoped_ids, flag_off.id
  end

  def test_aggregate_task_completion_stats_skips_units_outside_teaching_period
    now = Time.zone.now
    expired_period = FactoryBot.create(:teaching_period, start_date: now - 20.weeks, end_date: now - 2.weeks, active_until: now + 2.weeks)
    expired = create_unit(teaching_period: expired_period)
    current = create_unit

    AggregateTaskCompletionStatsJob.new.perform

    assert_equal 0, expired.task_completion_snapshots.count
    assert_equal 1, current.task_completion_snapshots.count
  end

  def test_refresh_moderation_feedback_timestamps_skips_units_outside_teaching_period
    now = Time.zone.now
    expired_period = FactoryBot.create(:teaching_period, start_date: now - 20.weeks, end_date: now - 2.weeks, active_until: now + 2.weeks)
    stale_time = 3.days.ago.change(usec: 0)

    expired_task = create_moderated_task(create_unit(teaching_period: expired_period, with_students: true, task_count: 1), stale_time)
    current_task = create_moderated_task(create_unit(with_students: true, task_count: 1), stale_time)

    RefreshModerationFeedbackTimestampsJob.new.perform

    assert_equal stale_time, expired_task.reload.last_tutor_feedback_at
    assert_nil current_task.reload.last_tutor_feedback_at
  end

  private

  def create_unit(teaching_period: nil, with_students: false, task_count: 0, **attrs)
    FactoryBot.create(
      :unit,
      teaching_period: teaching_period,
      with_students: with_students,
      task_count: task_count,
      outcome_count: 0,
      staff_count: 0,
      **attrs
    )
  end

  def create_moderated_task(unit, last_tutor_feedback_at)
    task = unit.active_projects.first.task_for_task_definition(unit.task_definitions.first)
    task.save! if task.new_record?
    task.update_column(:last_tutor_feedback_at, last_tutor_feedback_at)
    ModeratedTask.create!(task: task, task_definition: task.task_definition, state: :open, moderation_type: :first_feedback)
    task
  end
end
