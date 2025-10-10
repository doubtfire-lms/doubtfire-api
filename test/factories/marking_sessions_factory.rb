FactoryBot.define do
  factory :marking_session do
    association :user, factory: [:user, :tutor]
    association :unit
    ip_address { "192.168.1.1" }
    start_time { 1.hour.ago }
    end_time { Time.zone.now }
  end
end
