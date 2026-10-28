FactoryBot.define do
  factory :engagement do
    project
    user
    engagement_type { 'attendance' }
    note { 'Attended the weekly discussion.' }
    occurred_at { Time.zone.now }
  end

  factory :engagement_comment do
    engagement
    user
    comment { 'Thanks for recording this.' }
  end
end
