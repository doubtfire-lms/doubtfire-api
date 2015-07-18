# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :group_set do
  	sequence(:name) {|id| "Group Set #{id}" }
  	unit
  end
end
