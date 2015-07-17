# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do

  factory :tutorial do
    meeting_day       "Monday"
    meeting_time      "17:30"
    meeting_location  "ATC101"
    code              "LA1-01"
    abbreviation      "LA1-01"
    unit
  end

  factory :unit do
    name          "A"
    description   "Description"
    start_date    DateTime.now
    end_date      DateTime.now + 12.weeks
    code          "COS10001"
    active        true

    after(:create) do | unit, eval |
      create_list(:tutorial, 2, unit: unit)
    end
  end
end
