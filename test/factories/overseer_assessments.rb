FactoryBot.define do
  factory :overseer_assessment do
    submission_history
    task { submission_history.task }
    submission_timestamp { submission_history.submission_timestamp }
    result_task_status { "MyString" }
  end
end
