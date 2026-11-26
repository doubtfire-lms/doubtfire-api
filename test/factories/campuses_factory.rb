FactoryBot.define do
  factory :campus do
    name                { Faker::Educator.unique.campus }
    abbreviation        { name[0...9] }
    mode                { %w[timetable automatic manual].sample }
    active              { true }
  end
end
