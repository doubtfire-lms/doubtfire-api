require 'faker'

FactoryGirl.define do
  factory :tutorial do
    meeting_day               "Monday"
    meeting_time              "17:30"
    meeting_location          "ATC101"
    sequence(:abbreviation)   { |n| "T#{n}" }
    unit
    campus
    tutorial_stream           nil
  end
end
