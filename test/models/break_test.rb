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
  def test_start_date_is_within_teaching_period
    data = {
      year: 2023,
      period: 'T1',
      start_date: Date.parse('2023-01-05'),
      end_date: Date.parse('2023-02-05'),
      active_until: Date.parse('2023-03-05')
    }

    tp = TeachingPeriod.create(data)

    assert_raises ActiveRecord::RecordInvalid do
        b1 = tp.add_break('2023-01-02', 1)
    end 
  end
  
 def test_end_date_is_within_teaching_period
    data = {
      year: 2023,
      period: 'T1',
      start_date: Date.parse('2023-01-01'),
      end_date: Date.parse('2023-02-01'),
      active_until: Date.parse('2023-03-01')
    }

    tp = TeachingPeriod.create(data)
    assert_raises ActiveRecord::RecordInvalid do
    b1 = tp.add_break('2023-01-02', 5)
 end 
 end
end
