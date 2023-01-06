require 'faker'

FactoryBot.define do
  factory :tutorial do
    meeting_day               { "Monday" }
    meeting_time              { "17:30" }
    meeting_location          { "ATC101" }
    sequence(:abbreviation)   { |n| "T#{n}" }
    unit
    campus                    { Campus.offset(rand(Campus.count)).first || create(:campus) }
    tutorial_stream           { nil }
    unit_role                 { unit.staff.sample }
  end
end
