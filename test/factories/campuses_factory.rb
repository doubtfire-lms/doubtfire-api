FactoryGirl.define do
  factory :campus do
    sequence(:id, (4..50).cycle) { |n| n }
    name                { Faker::Educator.unique.campus }
    abbreviation        { name[0...9] }
    mode                { ['timetable', 'automatic', 'manual'].sample }
    active              true
  end
end
