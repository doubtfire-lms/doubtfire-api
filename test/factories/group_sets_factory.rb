# Read about factories at https://github.com/thoughtbot/factory_bot

FactoryBot.define do
  factory :group_set do
    sequence(:name) { |id| "Group Set #{id}" }
    keep_groups_in_same_class { false }
    allow_students_to_create_groups { true }
    allow_students_to_manage_groups { true }
    locked { false }
    unit
  end
end
