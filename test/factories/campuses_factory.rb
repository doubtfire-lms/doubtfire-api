FactoryGirl.define do
  factory :campus do
    sequence(:name)     { |n| "C#{n}-#{Faker::Educator.campus}" }
    abbreviation        { name[0...9] }
    mode                { ['timetable', 'automatic', 'manual'].sample }
    active              true
  end
end