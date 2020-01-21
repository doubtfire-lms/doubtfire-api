require 'date'
FactoryBot.define do
  factory :teaching_period do
    sequence(:period, (1..3).cycle)        { |n| "T#{n}" }
    sequence(:start_date, (1..3).cycle)    { |n| Time.zone.now + n * 15.weeks }
    year                     { start_date.year }
    end_date                 { start_date + 14.weeks }
    active_until             { end_date + rand(1..2).weeks }
  end
end
