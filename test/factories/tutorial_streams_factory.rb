FactoryGirl.define do
  factory :tutorial_stream do
    activity_type
    unit
    sequence(:name)                { |n| "#{activity_type.name}-#{n}" }
    sequence(:abbreviation)        { |n| "#{activity_type.abbreviation}-#{n}" }
  end
end
