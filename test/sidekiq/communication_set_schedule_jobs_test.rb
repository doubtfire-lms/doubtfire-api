require 'test_helper'

class CommunicationSetScheduleJobsTest < ActiveSupport::TestCase
  def test_poll_does_not_enqueue_schedules_for_inactive_units
    travel_to Time.zone.local(2026, 2, 2, 10, 0, 0) do
      active_schedule = create_due_schedule(unit_active: true)
      inactive_schedule = create_due_schedule(unit_active: false)

      PollCommunicationSetSchedulesJob.new.perform

      enqueued_schedule_ids = ExecuteCommunicationSetScheduleJob.jobs.map { |job| job['args'].first }
      assert_includes enqueued_schedule_ids, active_schedule.id
      assert_not_includes enqueued_schedule_ids, inactive_schedule.id
    end
  end

  def test_schedule_execution_does_not_enqueue_communication_set_for_inactive_unit
    travel_to Time.zone.local(2026, 2, 2, 10, 0, 0) do
      schedule = create_due_schedule(unit_active: false)

      ExecuteCommunicationSetScheduleJob.new.perform(schedule.id)

      assert_empty ExecuteCommunicationSetJob.jobs
      assert_nil schedule.reload.last_enqueued_at
      assert_nil schedule.last_run_at
    end
  end

  private

  def create_due_schedule(unit_active:)
    unit = FactoryBot.create(
      :unit,
      active: unit_active,
      with_students: false,
      task_count: 0,
      tutorials: 0,
      outcome_count: 0,
      staff_count: 0,
      campus_count: 0,
      start_date: Date.parse('2026-02-02'),
      end_date: Date.parse('2026-05-11')
    )
    communication_set = unit.communication_sets.create!(name: 'Scheduled communications', active: true)

    schedule = communication_set.communication_set_schedules.create!(
      name: 'Due schedule',
      active: true,
      anchor_week: 1,
      anchor_day: 'Monday',
      hour: 9,
      minute: 0,
      timezone: 'UTC',
      recurrence: 'none',
      interval: 1
    )
    schedule.update_column(:next_run_at, Time.zone.local(2026, 2, 2, 9, 0, 0))
    schedule
  end
end
