# Read about factories at https://github.com/thoughtbot/factory_bot

FactoryBot.define do
  factory :group do
    group_set

    sequence(:name)         { |n| "Group-#{n}" }

    after(:build) do |group, eval|
      if group.tutorial.nil?
        group.tutorial = group.group_set.unit.tutorials.first
      end
    end
  end
end
