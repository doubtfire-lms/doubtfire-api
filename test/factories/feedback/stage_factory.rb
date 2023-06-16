# Read about factories at https://github.com/thoughtbot/factory_bot

FactoryBot.define do

  factory :stage do

    association :task_definition

    transient do # transient: not persisted to database
      number_of_criterion {0} # `0` criteria created unless otherwise specified
      # E.g., "FactoryBot.create(:stage, number_of_criterion: 3)"
    end

    sequence(:order)          { |n| n }
    sequence(:title)          { |n| "Stage-#{n}" }
    help_text                 { Faker::Lorem.sentence }
    entry_message             { Faker::Lorem.sentence }
    exit_message_good         { Faker::Lorem.sentence }
    exit_message_resubmit     { Faker::Lorem.sentence }

    after(:create) do |stage, evaluator|
      create_list(:criteria, evaluator.number_of_criterion, stage: stage)
    end
  end
end
