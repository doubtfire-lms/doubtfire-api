FactoryBot.define do
  factory :overflow_task_claim_log do
    task { create(:task) }
    claimed_by_user_id { create(:user, :tutor).id }
    original_tutor_user_id { task.tutor&.id }
    student_user_id { task.project.student.id }
    claimed_at { Time.zone.now }
  end
end
