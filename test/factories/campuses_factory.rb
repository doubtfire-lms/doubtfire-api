FactoryGirl.define do
  factory :campus do
    id                  { rand(4..6)}
    name                { Faker::Educator.unique.campus }
    abbreviation        { name[0...9] }
    mode                { ['timetable', 'automatic', 'manual'].sample }
    active              true
  end
end
