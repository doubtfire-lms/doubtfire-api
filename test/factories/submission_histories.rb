FactoryBot.define do
  factory :submission_history do
    task
    sequence(:submission_timestamp) { |n| "#{Time.current.to_i}-#{n}" }
  end
end
