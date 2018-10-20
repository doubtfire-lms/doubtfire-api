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
    tp = TeachingPeriod.find(1)
    
    assert_equal tp.week_no(tp.breaks.first.start_date) + 1, tp.week_no(tp.breaks.first.start_date + tp.breaks.first.duration)
    assert_equal tp.week_no(tp.breaks.first.start_date), tp.week_no(tp.breaks.first.start_date + 1.day)
  end

  test 'can map week number to date' do
    tp = TeachingPeriod.first
    
    assert_equal tp.start_date, tp.date_for_week(1)
    assert_equal tp.start_date + 1.week, tp.date_for_week(2)
  end

  test 'can map week and day to date' do
    tp = TeachingPeriod.first
    
    assert_equal tp.start_date + 1.day, tp.date_for_week_and_day(1, 'Tue')
    assert_equal tp.start_date + 2.day + 1.week, tp.date_for_week_and_day(2, 'Wed')
    assert_equal tp.start_date + 3.day + 2.week, tp.date_for_week_and_day(3, 'Thu')
    assert_equal tp.start_date + 4.day + 2.week, tp.date_for_week_and_day(3, 'Fri')
    assert_equal tp.start_date + 5.day, tp.date_for_week_and_day(1, 'Sat')
    assert_equal tp.start_date - 1.day, tp.date_for_week_and_day(1, 'Sun')
  end

  test 'can map week and day to date after break' do
    tp = TeachingPeriod.find(2)
    
    start_of_break = tp.breaks.first.start_date
    end_of_break = tp.breaks.first.end_date
    break_in_cal_week = (start_of_break - tp.start_date) / 1.week + 1

    assert_equal end_of_break + 1.day, tp.date_for_week_and_day(break_in_cal_week, 'Tue')
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

  test 'week date works for initial weeks' do
  end

end
