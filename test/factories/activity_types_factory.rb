FactoryGirl.define do
  factory :activity_type do
    sequence(:name)      { |n| "Act#{n}-#{Faker::Name.name}" }
    abbreviation         { name[0...8] }
  end
end
