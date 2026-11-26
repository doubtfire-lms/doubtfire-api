FactoryBot.define do
  factory :task_completion_snapshot do
    unit
    snapshot_timestamp { Time.current.to_i.to_s }
  end
end
