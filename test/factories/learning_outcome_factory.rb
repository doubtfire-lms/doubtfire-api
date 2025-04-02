require 'faker'

FactoryBot.define do
  factory :learning_outcome do
    context_type { 'Unit' }
    context_id { 1 }
    sequence(:abbreviation) { |n| "O#{n}" }
    short_description { Faker::Lorem.sentence }
    full_outcome_description { Faker::Lorem.sentence }
    linked_outcome_ids { [] }
  end

  factory :learning_outcome_link do
    source_id { nil }
    target_id { nil }
  end
end
