class TeachingPeriod < ActiveRecord::Base
    has_many :units

    class << self
        def all_teaching_periods
            TeachingPeriod.all
        end        
    end

    def add_teaching_period (period, start_date, end_date)
        teaching_period = self
        teaching_period.period = period
        teaching_period.start_date = start_date
        teaching_period.end_date = end_date
        teaching_period.save!
        teaching_period
    end    
end
