require 'test_helper'

class CommunicationSetScheduleTest < ActiveSupport::TestCase
  def test_next_run_at_refreshes_when_unit_active_status_changes
    travel_to Time.zone.local(2026, 1, 1, 9, 0, 0) do
      unit = FactoryBot.create(
        :unit,
        active: true,
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
        name: 'Week 1 Monday',
        active: true,
        anchor_week: 1,
        anchor_day: 'Monday',
        hour: 9,
        minute: 30,
        timezone: 'UTC',
        recurrence: 'none',
        interval: 1
      )

      assert_equal Time.zone.local(2026, 2, 2, 9, 30, 0), schedule.next_run_at

      unit.update!(active: false)
      assert_nil schedule.reload.next_run_at

      unit.update!(active: true)
      assert_equal Time.zone.local(2026, 2, 2, 9, 30, 0), schedule.reload.next_run_at
    end
  end
end
