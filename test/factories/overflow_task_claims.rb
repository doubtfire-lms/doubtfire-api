FactoryBot.define do
  factory :overflow_task_claim do
    task
    claimed_by_unit_role { create(:unit_role, unit: task.project.unit, user: create(:user, :tutor), role: Role.tutor) }
  end
end
