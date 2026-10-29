require 'test_helper'

class TeachingPeriodTest < ActiveSupport::TestCase

  def test_last_teaching_date_defaults_to_end_date_and_propagates_to_units
    teaching_period = FactoryBot.create(:teaching_period)
    unit = FactoryBot.create(:unit, teaching_period: teaching_period, with_students: false)

    assert_equal teaching_period.end_date.to_date, teaching_period.last_teaching_date
    assert_equal teaching_period.last_teaching_date, unit.last_teaching_date

    last_teaching_date = teaching_period.end_date.to_date - 1.week
    teaching_period.update!(last_teaching_date: last_teaching_date)

    assert_equal last_teaching_date, unit.reload.last_teaching_date
    assert_equal teaching_period.end_date, unit.end_date
  end

  def test_last_teaching_date_must_be_within_the_teaching_period
    teaching_period = FactoryBot.build(:teaching_period)
    teaching_period.last_teaching_date = teaching_period.end_date.to_date + 1.day

    assert_not teaching_period.valid?
    assert_includes teaching_period.errors.attribute_names, :last_teaching_date
  end

  def test_default_last_teaching_date_follows_end_date_changes
    teaching_period = FactoryBot.create(:teaching_period)
    unit = FactoryBot.create(:unit, teaching_period: teaching_period, with_students: false)
    original_end_date = teaching_period.end_date
    earlier_end_date = original_end_date - 1.week

    teaching_period.update!(end_date: earlier_end_date)

    assert_equal earlier_end_date.to_date, teaching_period.last_teaching_date
    assert_equal earlier_end_date.to_date, unit.reload.last_teaching_date

    custom_last_teaching_date = earlier_end_date.to_date - 1.week
    teaching_period.update!(last_teaching_date: custom_last_teaching_date)
    teaching_period.update!(end_date: original_end_date)

    assert_equal custom_last_teaching_date, teaching_period.last_teaching_date
    assert_equal custom_last_teaching_date, unit.reload.last_teaching_date
  end

  # Ensure that at the start there are 3 teaching periods
  def test_check_periods_are_created
    assert_equal 3, TeachingPeriod.count, 'There are 3 teaching periods initially'
  end

  # Check that units cannot be created with both TP and custom dates
  def test_create_unit_with_tp_and_dates
    tp = TeachingPeriod.first

    data = {
      name: 'Unit with error',
      code: 'TEST111',
      teaching_period: tp,
      description: 'Unit with both TP and start date',
      start_date: Date.parse('2018-01-01'),
      end_date: Date.parse('2018-02-01')
    }

    unit = Unit.create(data)
    assert_not unit.valid?
  end

  # Check that you can create a teaching period
  def test_create_teaching_period
    data = {
      year: 2019,
      period: 'T1',
      start_date: Date.parse('2018-01-01'),
      end_date: Date.parse('2018-02-01'),
      active_until: Date.parse('2018-03-01')
    }

    tp = TeachingPeriod.create(data)
    assert tp.valid?
  end

  # Test invalid dates
  def test_create_teaching_period_with_invalid_dates
    data = {
      year: 2019,
      period: 'T1',
      start_date: Date.parse('2018-01-01'),
      end_date: Date.parse('2018-02-01'),
      active_until: Date.parse('2017-03-01')
    }

    tp = TeachingPeriod.create(data)
    assert_not tp.valid?

    data = {
      year: 2019,
      period: 'T1',
      start_date: Date.parse('2018-01-01'),
      end_date: Date.parse('2017-02-01'),
      active_until: Date.parse('2018-03-01')
    }

    tp = TeachingPeriod.create(data)
    assert_not tp.valid?

    # Check that unit requires both start and end dates
    data = {
      year: 2019,
      period: 'T1',
      start_date: Date.parse('2018-01-01'),
      active_until: Date.parse('2018-03-01')
    }

    tp = TeachingPeriod.create(data)
    assert_not tp.valid?

    data = {
      year: 2019,
      period: 'T1',
      end_date: Date.parse('2018-01-01'),
      active_until: Date.parse('2018-03-01')
    }

    tp = TeachingPeriod.create(data)
    assert_not tp.valid?
  end

  test 'week 1 is first week of teaching period' do
    tp = TeachingPeriod.first

    assert_equal 1, tp.week_number(tp.start_date)
  end

  test 'weeks advance with calendar weeks' do
    tp = TeachingPeriod.first

    assert_equal 2, tp.week_number(tp.start_date + 1.week)
  end

  test 'weeks advance with breaks' do
    tp = TeachingPeriod.find(1)

    assert_equal tp.week_number(tp.breaks.first.start_date) + 1, tp.week_number(tp.breaks.first.end_date)
    assert_equal tp.week_number(tp.breaks.first.start_date), tp.week_number(tp.breaks.first.start_date + 1.day)
  end

  test 'can map week number to date' do
    tp = TeachingPeriod.first

    assert_equal tp.start_date, tp.date_for_week(1)
    assert_equal tp.start_date + 1.week, tp.date_for_week(2)
  end

  test 'can map week and day to date' do
    tp = TeachingPeriod.first

    assert_equal tp.start_date + 1.day, tp.date_for_week_and_day(1, 'Tue')
    assert_equal tp.start_date + 2.days + 1.week, tp.date_for_week_and_day(2, 'Wed')
    assert_equal tp.start_date + 3.days + 2.weeks, tp.date_for_week_and_day(3, 'Thu')
    assert_equal tp.start_date + 4.days + 2.weeks, tp.date_for_week_and_day(3, 'Fri')
    assert_equal tp.start_date + 5.days, tp.date_for_week_and_day(1, 'Sat')
    assert_equal tp.start_date + 6.days, tp.date_for_week_and_day(1, 'Sun')
  end

  test 'can map week and day to date after break' do
    tp = TeachingPeriod.find(2)

    start_of_break = tp.breaks.first.start_date
    end_of_break = tp.breaks.first.end_date
    break_in_cal_week = ((start_of_break - tp.start_date) / 1.week).ceil + 1 # as mon break

    assert_equal end_of_break + 1.day, tp.date_for_week_and_day(break_in_cal_week, 'Tue')
  end

  test 'Test date for week and day where day ends on break' do
    tp = TeachingPeriod.find(1)

    start_of_break = tp.breaks.first.start_date
    end_of_break = tp.breaks.first.end_date
    break_in_cal_week = ((start_of_break - tp.start_date) / 1.week).ceil # no + 1 as fri

    assert_equal end_of_break, tp.date_for_week_and_day(break_in_cal_week, 'Fri')
  end

  test 'can map week number to date across breaks' do
    tp = TeachingPeriod.find(2)

    break_in_cal_week = ((tp.breaks.first.start_date - tp.start_date) / 1.week).ceil + 1 # + 1 as mon break
    assert_equal tp.breaks.first.start_date + tp.breaks.first.number_of_days.days, tp.date_for_week(break_in_cal_week)
  end

  test 'can map week number to date across breaks starting friday' do
    tp = TeachingPeriod.find(1)

    break_in_cal_week = ((tp.breaks.first.start_date - tp.start_date) / 1.week).ceil # no +1 as Fri
    assert_equal tp.breaks.first.start_date - 4.days, tp.date_for_week(break_in_cal_week)
    assert_equal tp.breaks.first.start_date + tp.breaks.first.number_of_days.days + 3.days, tp.date_for_week(break_in_cal_week + 1)
  end

  test 'week number works with mult-week breaks' do
    tp = TeachingPeriod.find(3)

    assert_equal tp.week_number(tp.breaks.first.start_date) + 1, tp.week_number(tp.breaks.first.end_date)
    assert_equal 14, tp.breaks.first.number_of_days
  end

  test 'check end date' do
    TeachingPeriod.all.each do |tp|
      assert_equal tp.breaks.first.start_date + tp.breaks.first.number_of_days.days, tp.breaks.first.end_date
    end
  end

  test 'week number continues through breaks that do not pause the week count' do
    tp = TeachingPeriod.create!(
      period: 'PWC1',
      year: 2025,
      start_date: Date.parse('2025-03-03'), # a Monday
      end_date: Date.parse('2025-06-09'),
      active_until: Date.parse('2025-06-30')
    )

    teaching_break = tp.add_break(tp.start_date + 4.weeks, 7)
    monday_after_break = tp.start_date + 5.weeks

    # the break pauses the count, so the week after the break is still week 5
    assert_equal 5, tp.week_number(monday_after_break)

    teaching_break.update!(pause_week_count: false)
    tp.reload

    # without pausing, the week count runs straight through the break
    assert_equal 6, tp.week_number(monday_after_break)
  end

  test 'date for week ignores breaks that do not pause the week count' do
    tp = TeachingPeriod.create!(
      period: 'PWC2',
      year: 2025,
      start_date: Date.parse('2025-03-03'), # a Monday
      end_date: Date.parse('2025-06-09'),
      active_until: Date.parse('2025-06-30')
    )

    teaching_break = tp.add_break(tp.start_date + 4.weeks, 7)

    # the break pushes week 6 out by its duration
    assert_equal tp.start_date + 6.weeks, tp.date_for_week(6)

    teaching_break.update!(pause_week_count: false)
    tp.reload

    assert_equal tp.start_date + 5.weeks, tp.date_for_week(6)
  end

  test 'week numbers stay aligned across campuses when a campus break does not pause the week count' do
    tp = TeachingPeriod.create!(
      period: 'PWC3',
      year: 2025,
      start_date: Date.parse('2025-03-03'), # a Monday
      end_date: Date.parse('2025-06-09'),
      active_until: Date.parse('2025-06-30')
    )

    main_campus = FactoryBot.create(:campus)
    other_main_campus = FactoryBot.create(:campus)
    late_campus = FactoryBot.create(:campus)

    # most campuses share a mid semester break, which pauses the week count
    main_break = tp.add_break(tp.start_date + 4.weeks, 7, [main_campus.id, other_main_campus.id], 'Mid semester break')
    # this campus takes its break a week later - the week count runs on through
    # it so that every campus is in the same teaching week
    late_break = tp.add_break(tp.start_date + 5.weeks, 7, [late_campus.id], 'Late mid semester break', false)

    assert_equal [main_break], tp.week_pausing_breaks

    # only the main break moves the week number, for all campuses
    assert_equal 5, tp.week_number(tp.start_date + 5.weeks)
    assert_equal 7, tp.week_number(tp.start_date + 7.weeks)

    # each break still applies to its own campuses, so deadlines are extended
    assert_equal [main_break], tp.breaks_for(main_campus)
    assert_equal [late_break], tp.breaks_for(late_campus)
  end

  test 'check break next monday' do
    tp = TeachingPeriod.first

    assert_equal tp.date_for_week(5), tp.breaks.first.monday_after_break
  end

  test 'cannot destroy teaching period with units' do
    data = {
      year: 2019,
      period: 'T1',
      start_date: Date.parse('2018-01-01'),
      end_date: Date.parse('2018-02-01'),
      active_until: Date.parse('2018-03-01')
    }

    tp = TeachingPeriod.create(data)

    data = {
      name: 'Unit with TP',
      code: 'TEST112',
      teaching_period: tp,
      description: 'Unit in TP to stop destroy'
    }

    unit = Unit.create(data)

    assert tp.units.count > 0
    tp.destroy
  rescue StandardError
    assert_not tp.destroyed?
  end

  test 'can destroy teaching period with breaks' do
    data = {
      year: 2019,
      period: 'T1',
      start_date: Date.parse('2018-01-01'),
      end_date: Date.parse('2018-02-01'),
      active_until: Date.parse('2018-03-01')
    }

    tp = TeachingPeriod.create(data)

    tp.add_break(tp.date_for_week(3), 7)

    assert tp.breaks.count > 0
    tp.destroy
    assert tp.destroyed?
  end

  test 'communication schedule next run refreshes when breaks change' do
    travel_to Time.zone.local(2026, 1, 1, 9, 0, 0) do
      tp = TeachingPeriod.create!(
        year: 2026,
        period: 'T1',
        start_date: Date.parse('2026-02-02'),
        end_date: Date.parse('2026-05-11'),
        active_until: Date.parse('2026-05-18')
      )
      unit = FactoryBot.create(:unit, teaching_period: tp, with_students: false, task_count: 0, tutorials: 0, outcome_count: 0, staff_count: 0, campus_count: 0)
      communication_set = unit.communication_sets.create!(name: 'Weekly check in', active: true)
      schedule = communication_set.communication_set_schedules.create!(
        name: 'Week 3 Monday',
        active: true,
        anchor_week: 3,
        anchor_day: 'Monday',
        hour: 9,
        minute: 30,
        timezone: 'UTC',
        recurrence: 'none',
        interval: 1
      )

      assert_equal Time.zone.local(2026, 2, 16, 9, 30, 0), schedule.next_run_at

      teaching_break = tp.add_break(Date.parse('2026-02-09'), 7)
      assert_equal Time.zone.local(2026, 2, 23, 9, 30, 0), schedule.reload.next_run_at

      tp.update_break(teaching_break.id, Date.parse('2026-02-23'), 7)
      assert_equal Time.zone.local(2026, 2, 16, 9, 30, 0), schedule.reload.next_run_at

      teaching_break.destroy
      assert_equal Time.zone.local(2026, 2, 16, 9, 30, 0), schedule.reload.next_run_at
    end
  end
end
