FactoryGirl.define do
  factory :teaching_period do
    sequence(:period)        { |n| "T#{n}" }
    start_date               { Faker::Date.between(2.days.ago, Date.today) }
    year                     { start_date.year }
    end_date                 { start_date + 14.weeks }
    active_until             { end_date + rand(1..2).weeks }
  end
end
