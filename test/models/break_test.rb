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

    b1 = tp.add_break('2023-01-02', 1)
    exception = assert_raises(ActiveRecord::RecordInvalid) {tp.add_break('2023-01-03', 1)}
    assert_equal("Validation failed: overlaps another break", exception.message)
    assert b1.valid?, "b1 not valid"
    assert_equal 1, tp.breaks.count
  end

  def test_overlapping_breaks_are_allowed_for_different_campuses
    teaching_period = FactoryBot.create(:teaching_period)
    first_campus = FactoryBot.create(:campus)
    second_campus = FactoryBot.create(:campus)
    start_date = teaching_period.start_date + 2.weeks

    first_break = teaching_period.add_break(start_date, 1, [first_campus.id])
    second_break = teaching_period.add_break(start_date, 1, [second_campus.id])

    assert_equal [first_break], teaching_period.breaks_for(first_campus)
    assert_equal [second_break], teaching_period.breaks_for(second_campus)
    assert_empty teaching_period.breaks_for(nil)
  end
end
