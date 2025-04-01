FactoryBot.define do
  factory :overseer_image do
    name { Faker::Lorem.unique.word }
    sequence(:tag) { |n| "host/testtag:v#{n}-#{rand(0..100)}" }
    pulled_image_text { Faker::Lorem.sentence }
    pulled_image_status { rand(0..1) }
    last_pulled_date { Faker::Date.between(from: 2.days.ago, to: Time.zone.today) }
  end
end
