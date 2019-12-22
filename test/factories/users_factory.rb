require 'faker'

FactoryGirl.define do
  factory :user do
    first_name  { Faker::Name.first_name }
    last_name   { Faker::Name.last_name }
    username    { Faker::Internet.unique.username }
    email       { Faker::Internet.unique.safe_email }
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
