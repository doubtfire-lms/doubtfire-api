# Read about factories at https://github.com/thoughtbot/factory_bot

FactoryBot.define do
  factory :group do
    group_set

    sequence(:number)       { |n| n }
    name                    { Populator.words(1..3) }

    after(:build) do |group, eval|
      if group.tutorial.nil?
        group.tutorial = group.group_set.unit.tutorials.first
      end
    end
  end
end
