require 'test_helper'

class BreakTest < ActiveSupport::TestCase
  def test_breaks_not_colliding
    data = {
      year: 2023,
      period: 'T1',
      start_date: Date.parse('2023-01-01'),
      end_date: Date.parse('2023-02-01'),
      active_until: Date.parse('2023-03-01')
    }

    tp = TeachingPeriod.create(data)

    b1 = tp.add_break('2023-01-02', 7)
    exception = assert_raises(ActiveRecord::RecordInvalid) { tp.add_break('2023-01-03', 7) }
    assert_equal("Validation failed: overlaps another break", exception.message)
    assert b1.valid?, "b1 not valid"
    assert_equal 1, tp.breaks.count
  end

  def test_overlapping_breaks_are_allowed_for_different_campuses
    teaching_period = FactoryBot.create(:teaching_period)
    first_campus = FactoryBot.create(:campus)
    second_campus = FactoryBot.create(:campus)
    start_date = teaching_period.start_date + 2.weeks

    first_break = teaching_period.add_break(start_date, 7, [first_campus.id])
    second_break = teaching_period.add_break(start_date, 7, [second_campus.id])

    assert_equal [first_break], teaching_period.breaks_for(first_campus)
    assert_equal [second_break], teaching_period.breaks_for(second_campus)
    assert_empty teaching_period.breaks_for(nil)
  end

  def test_pause_week_count_defaults_to_true
    teaching_period = FactoryBot.create(:teaching_period)

    teaching_break = teaching_period.add_break(teaching_period.start_date + 2.weeks, 7)

    assert teaching_break.pause_week_count, 'breaks should pause the week count by default'
  end

  def test_pause_week_count_requires_whole_weeks
    teaching_period = FactoryBot.create(:teaching_period)
    start_date = teaching_period.start_date + 2.weeks

    exception = assert_raises(ActiveRecord::RecordInvalid) do
      teaching_period.add_break(start_date, 5, [], nil, true)
    end
    assert_equal 'Validation failed: Pause week count can only be set on breaks that are a multiple of 7 days', exception.message

    # the same break is fine when it leaves the week count running
    teaching_break = teaching_period.add_break(start_date, 5, [], nil, false)
    assert teaching_break.valid?
    assert_not teaching_break.pause_week_count
  end

  def test_pause_week_count_is_allowed_for_multi_week_breaks
    teaching_period = FactoryBot.create(:teaching_period)

    teaching_break = teaching_period.add_break(teaching_period.start_date + 2.weeks, 14, [], nil, true)

    assert teaching_break.valid?
    assert teaching_break.pause_week_count
  end

  def test_pausing_break_cannot_be_shortened_to_a_partial_week
    teaching_period = FactoryBot.create(:teaching_period)
    teaching_break = teaching_period.add_break(teaching_period.start_date + 2.weeks, 7, [], nil, true)

    exception = assert_raises(ActiveRecord::RecordInvalid) do
      teaching_period.update_break(teaching_break.id, nil, 5)
    end
    assert_equal 'Validation failed: Pause week count can only be set on breaks that are a multiple of 7 days', exception.message
  end
end
