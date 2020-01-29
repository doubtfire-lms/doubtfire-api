# Read about factories at https://github.com/thoughtbot/factory_bot

FactoryBot.define do
  factory :group_set do
  	sequence(:name) {|id| "Group Set #{id}" }
  	unit
  end
end
