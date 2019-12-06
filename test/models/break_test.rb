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
    #test if date of break overlaps another break, does the system show the fail message or not
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

    exception = assert_raises(ActiveRecord::RecordInvalid) {tp.add_break('2023-01-04', 1)}
    #test if date of break before start date, does the system show the fail message or not
    assert_equal("Validation failed: Start date should be after the Teaching Period start date", exception.message)

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
    exception = assert_raises (ActiveRecord::RecordInvalid){b1 = tp.add_break('2023-01-02', 5)}
    #test if break time exceed the end date, does the system show the fail message or not
    assert_equal("Validation failed: Number of weeks is exceeding Teaching Period end date", exception.message)
    end 

 def test_monday_after_break
     data = {
      year: 2019,
      period: 'T1',
      start_date: Date.parse('2019-01-01'),
      end_date: Date.parse('2019-02-01'),
      active_until: Date.parse('2019-03-01')
    }

    tp = TeachingPeriod.create(data)
    tp.add_break(tp.date_for_week(3), 1)
    br = tp.breaks.first 

    noWeeks = br.number_of_weeks.weeks
    #test the first monday which after 3-weeks break is 28th or not
    assert_equal br.monday_after_break, '2019-01-28'
  end 


end
