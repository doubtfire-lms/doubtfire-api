# Read about factories at https://github.com/thoughtbot/factory_bot

FactoryBot.define do

  factory :check_in do
    room
    id_card
    checkin_at { Time.zone.now - 5.seconds }
  end
end
