require 'test_helper'

class BreakTest < ActiveSupport::TestCase
  def test_breaks_not_colliding
    data = {
      year: 2019,
      period: 'T1',
      start_date: Date.parse('2018-01-01'),
      end_date: Date.parse('2018-02-01'),
      active_until: Date.parse('2018-03-01')
    }

    tp = TeachingPeriod.create(data)

    b1 = tp.add_break('2018-01-02', 1)
    b2 = tp.add_break('2018-01-03', 1)

    assert b1.valid?, "b1 not valid"
    assert_not b2.valid?, "b2 is valid"
    assert_equal 1, tp.breaks.count
    assert_equal 1, b2.errors.count
  end
end