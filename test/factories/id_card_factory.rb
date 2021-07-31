# Read about factories at https://github.com/thoughtbot/factory_bot

FactoryBot.define do
  factory :id_card do
    card_number { Faker::Lorem.characters(number: 15) }
  end
end
