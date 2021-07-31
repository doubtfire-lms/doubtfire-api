# Read about factories at https://github.com/thoughtbot/factory_bot

FactoryBot.define do

  factory :room do
    room_number { Faker::Lorem.characters(number: 5) }
  end
end
