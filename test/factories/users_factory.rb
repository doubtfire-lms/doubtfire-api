require 'faker'

FactoryBot.define do
  factory :user do
    username    { Faker::Internet.user_name }
    email       { Faker::Internet.email }
    first_name  { Faker::Name.first_name }
    last_name   { Faker::Name.last_name }
    password    { "password" }
    role        { Role.student }

    trait :student do
    end

    trait :tutor do
      role      { Role.tutor }
    end

    trait :admin do
      role      { Role.admin }
    end

    trait :convenor do
      role      { Role.convenor }
    end

  end
end
