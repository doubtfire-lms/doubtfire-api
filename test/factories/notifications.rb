FactoryBot.define do
  factory :notification do
    recipient { create(:user) }
    unit { create(:unit, with_students: false, task_count: 0) }
    kind { 'new_task_comment' }
    sequence(:deduplication_key) { |number| "factory-notification-#{number}" }
  end

  factory :notification_setting do
    user
    digest_frequency { 'weekly' }
    digest_time { '07:00' }
    digest_weekday { 1 }
  end

  factory :notification_unit_override do
    user
    unit { create(:unit, with_students: false, task_count: 0) }
    muted { false }
  end
end
