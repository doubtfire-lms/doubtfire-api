FactoryBot.define do
  factory :notification do
    recipient { create(:user) }
    unit { create(:unit, with_students: false, task_count: 0) }
    kind { 'feedback_left' }
    sequence(:deduplication_key) { |number| "factory-notification-#{number}" }
    metadata { {} }
  end

  factory :notification_preference do
    user
    unit { create(:unit, with_students: false, task_count: 0) }
    email_categories { Notification::KINDS }
    email_frequency { 'weekly' }
    email_time { '09:00' }
    email_weekday { 1 }
    timezone { 'UTC' }
  end
end
