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
    
    assert_equal tp.week_no(tp.breaks.first.start_date) + 1, tp.week_no(tp.breaks.first.end_date)
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
    assert_equal tp.breaks.first.start_date + tp.breaks.first.number_of_weeks.week, tp.date_for_week(break_in_cal_week)
  end

  test 'can map week number to date across breaks starting friday' do
    tp = TeachingPeriod.find(1)
    
    break_in_cal_week = ((tp.breaks.first.start_date - tp.start_date) / 1.week).ceil # no +1 as Fri
    assert_equal tp.breaks.first.start_date - 4.days, tp.date_for_week(break_in_cal_week)
    assert_equal tp.breaks.first.start_date + tp.breaks.first.number_of_weeks.week + 3.days, tp.date_for_week(break_in_cal_week + 1)
  end

  test 'week number works with mult-week breaks' do
    tp = TeachingPeriod.find(3)
    
    assert_equal tp.week_no(tp.breaks.first.start_date) + 1, tp.week_no(tp.breaks.first.end_date)
    assert_equal 2, tp.breaks.first.number_of_weeks
  end

  test 'check end date' do
    TeachingPeriod.all.each do |tp|
      assert_equal tp.breaks.first.start_date + tp.breaks.first.number_of_weeks.weeks, tp.breaks.first.end_date
    end
  end

  test 'check break next monday' do
    tp = TeachingPeriod.first

    assert_equal tp.date_for_week(5), tp.breaks.first.monday_after_break
  end

  test 'week date works for initial weeks' do
  end

end
