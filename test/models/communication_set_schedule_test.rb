require 'test_helper'

class CommunicationSetScheduleTest < ActiveSupport::TestCase
  def test_next_run_at_is_nil_when_next_occurrence_is_after_unit_end_date
    travel_to Time.zone.local(2026, 1, 1, 9, 0, 0) do
      unit = create_unit(start_date: Date.parse('2026-02-02'), end_date: Date.parse('2026-02-02'))
      schedule = create_schedule(unit, anchor_day: 'Tuesday')

      assert_nil schedule.next_run_at
    end
  end

  def test_next_run_at_refreshes_when_unit_dates_change
    travel_to Time.zone.local(2026, 1, 1, 9, 0, 0) do
      unit = create_unit(start_date: Date.parse('2026-02-02'), end_date: Date.parse('2026-02-10'))
      schedule = create_schedule(unit, anchor_day: 'Tuesday')

      assert_equal Time.zone.local(2026, 2, 3, 9, 30, 0), schedule.next_run_at

      unit.update!(end_date: Date.parse('2026-02-02'))
      assert_nil schedule.reload.next_run_at

      unit.update!(start_date: Date.parse('2026-02-09'), end_date: Date.parse('2026-02-17'))
      assert_equal Time.zone.local(2026, 2, 10, 9, 30, 0), schedule.reload.next_run_at
    end
  end

  def test_next_run_at_refreshes_when_unit_active_status_changes
    travel_to Time.zone.local(2026, 1, 1, 9, 0, 0) do
      unit = create_unit(start_date: Date.parse('2026-02-02'), end_date: Date.parse('2026-05-11'))
      schedule = create_schedule(unit, anchor_day: 'Monday')

      assert_equal Time.zone.local(2026, 2, 2, 9, 30, 0), schedule.next_run_at

      unit.update!(active: false)
      assert_nil schedule.reload.next_run_at

      unit.update!(active: true)
      assert_equal Time.zone.local(2026, 2, 2, 9, 30, 0), schedule.reload.next_run_at
    end
  end

  private

  def create_unit(start_date:, end_date:)
    FactoryBot.create(
      :unit,
      active: true,
      with_students: false,
      task_count: 0,
      tutorials: 0,
      outcome_count: 0,
      staff_count: 0,
      campus_count: 0,
      start_date: start_date,
      end_date: end_date
    )
  end

  def create_schedule(unit, anchor_day:)
    communication_set = unit.communication_sets.create!(name: 'Scheduled communications', active: true)
    communication_set.communication_set_schedules.create!(
      name: 'Week 1 schedule',
      active: true,
      anchor_week: 1,
      anchor_day: anchor_day,
      hour: 9,
      minute: 30,
      timezone: 'UTC',
      recurrence: 'none',
      interval: 1
    )
  end
end
