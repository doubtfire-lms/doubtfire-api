# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :outcome_task_link do
    description "MyText"
    rating 1
    task_definition nil
    task nil
  end
end
