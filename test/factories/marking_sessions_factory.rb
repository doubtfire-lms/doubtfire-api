FactoryBot.define do
  factory :marking_session do
    association :marker, factory: [:user, :tutor]
    association :unit
    ip_address { "192.168.1.1" }
    start_time { 1.hour.ago }
    duration_minutes { 60 }
  end
end
