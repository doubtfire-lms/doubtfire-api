# Read about factories at https://github.com/thoughtbot/factory_bot

FactoryBot.define do
  factory :stage do
    transient do
      number_of_criterion {0}
    end

    task_definition

    sequence(:order)          { |n| n }
    sequence(:title)          { |n| "Stage-#{n}" }

    help_text                 { Faker::Lorem.sentence }
    entry_message             { Faker::Lorem.sentence }
    exit_message_good         { Faker::Lorem.sentence }
    exit_message_resubmit     { Faker::Lorem.sentence }

    after(:build) do |stage, eval|
      # Create a list of criterion that refer to the created stage
      create_list(:criteria, eval.number_of_criterion, stage: stage)
    end
  end
end
