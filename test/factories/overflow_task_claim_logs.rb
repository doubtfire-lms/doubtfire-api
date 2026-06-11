FactoryBot.define do
  factory :overflow_task_claim_log do
    task { create(:task) }
    unit { task.project.unit }
    claimed_by_unit_role do
      create(:unit_role, unit: unit, user: create(:user, :tutor), role: Role.tutor)
    end
    claimed_by_user { claimed_by_unit_role.user }
    original_tutor_user_id { task.tutor&.id }
    student_user_id { task.project.student.id }
    days_awaiting_feedback { task.days_awaiting_feedback }
    claimed_at { Time.zone.now }
  end
end
