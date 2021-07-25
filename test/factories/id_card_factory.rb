# Read about factories at https://github.com/thoughtbot/factory_bot

FactoryBot.define do
  factory :id_card do
    id_card
    room
    checkin_at { Faker::Time.backward }
  end
end
