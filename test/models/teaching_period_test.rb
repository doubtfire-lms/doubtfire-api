require 'test_helper'

class TeachingPeriodTest < ActiveSupport::TestCase
  
  test 'week 1 is first week of teaching period' do
    tp = TeachingPeriod.first
    
    assert_equal 1, tp.week_no(tp.start_date)
  end

  test 'weeks advance with calendar weeks' do
    tp = TeachingPeriod.first
    
    assert_equal 2, tp.week_no(tp.start_date + 1.week)
  end

  test 'weeks advance with breaks' do
    tp = TeachingPeriod.find(2)
    
    assert_equal tp.week_no(tp.breaks.first.start_date) + 1, tp.week_no(tp.breaks.first.start_date + tp.breaks.first.duration)
    assert_equal tp.week_no(tp.breaks.first.start_date) + 1, tp.week_no(tp.breaks.first.start_date + tp.breaks.first.duration)
  end

  test 'can map week number to date' do
    tp = TeachingPeriod.first
    
    assert_equal tp.start_date, tp.date_for_week(1)
    assert_equal tp.start_date + 1.week, tp.date_for_week(2)
  end

  test 'can map week number to date across breaks' do
    tp = TeachingPeriod.first
    
    break_in_cal_week = (tp.breaks.first.start_date - tp.start_date) / 1.week + 1
    assert_equal tp.breaks.first.start_date + tp.breaks.first.number_of_weeks.week, tp.date_for_week(break_in_cal_week)
  end

  test 'week number works with mult-week breaks' do
    tp = TeachingPeriod.find(3)
    
    assert_equal tp.week_no(tp.breaks.first.start_date) + 1, tp.week_no(tp.breaks.first.start_date + tp.breaks.first.number_of_weeks.weeks)
    assert_equal 2, tp.breaks.first.number_of_weeks
  end

end
