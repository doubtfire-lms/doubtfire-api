FactoryBot.define do
  factory :task_pin do
    task { FactoryBot.create(:task) }
    user { task.unit.main_convenor_user }
  end
end
