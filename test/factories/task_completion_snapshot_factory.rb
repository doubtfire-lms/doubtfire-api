FactoryBot.define do
  factory :task_completion_snapshot do
    unit
    snapshot_date { Date.current }
    captured_at { Time.current }
    stats { { 'completed' => 5, 'in_progress' => 3, 'not_started' => 2 } }
  end
end
