require 'test_helper'

class TeachingPeriodTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_check_periods_are_created
    # Ensure that at the start there are 3 teaching periods
    assert_equal 3, TeachingPeriod.count, 'There are 3 teaching periods initially' 
  end

  # Check that units cannot be created with both TP and custom dates
  def test_create_unit_with_tp_and_dates
    tp = TeachingPeriod.first

    data = {
        name: 'Unit with error',
        code: 'TEST111',
        teaching_period_id: tp.id,
        description: 'Unit with both TP and start date',
        start_date: Date.parse('2018-01-01'),
        end_date: Date.parse('2018-02-01')
    }

    unit = Unit.create(data)
    refute unit.valid?
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
    refute tp.valid?

    data = {
        year: 2019,
        period: 'T1',
        start_date: Date.parse('2018-01-01'),
        end_date: Date.parse('2017-02-01'),
        active_until: Date.parse('2018-03-01')
    }

    tp = TeachingPeriod.create(data)
    refute tp.valid?

    # Check that unit requires both start and end dates
    data = {
        year: 2019,
        period: 'T1',
        start_date: Date.parse('2018-01-01'),
        active_until: Date.parse('2018-03-01')
    }

    tp = TeachingPeriod.create(data)
    refute tp.valid?

    data = {
        year: 2019,
        period: 'T1',
        end_date: Date.parse('2018-01-01'),
        active_until: Date.parse('2018-03-01')
    }

    tp = TeachingPeriod.create(data)
    refute tp.valid?

  end

end
