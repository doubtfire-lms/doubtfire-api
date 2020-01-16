FactoryBot.define do
  factory :campus do
    name                { Faker::Educator.unique.campus }
    abbreviation        { name[0...9] }
    mode                { ['timetable', 'automatic', 'manual'].sample }
    active              { true }
  end
end
