FactoryGirl.define do
  factory :teaching_period do
    period       "6"
    year      "2019"
    start_date  Date.new(2019,3,4)
    end_date  { start_date + rand(1..2).weeks }
    active_until { end_date + rand(1..2).weeks }
  end
end
