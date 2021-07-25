# Read about factories at https://github.com/thoughtbot/factory_bot

FactoryBot.define do

  factory :check_in do
    room_number { Faker::Lorem.characters(5) }
  end
end
