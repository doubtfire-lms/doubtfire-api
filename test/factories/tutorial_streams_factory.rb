FactoryBot.define do
  factory :tutorial_stream do
    unit
    activity_type                  { ActivityType.all.sample }
    sequence(:name)                { |n| "#{activity_type.name}-#{n}" }
    sequence(:abbreviation)        { |n| "#{activity_type.abbreviation}-#{n}" }
  end
end
