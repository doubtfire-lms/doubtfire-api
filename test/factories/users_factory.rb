require 'faker'

FactoryBot.define do
  factory :user do
    first_name  { Faker::Name.first_name }
    last_name   { Faker::Name.last_name }
    username    { "factory-#{Faker::Internet.unique.username}" }
    email       { Faker::Internet.unique.safe_email }
    password    { "password" }
    role        { Role.student }

    trait :student do
      transient do
        enrol_in    { 0 }     # Number of units to enrol into
      end

      after(:create) do |user, eval|
        eval.enrol_in.times do
          unit = FactoryBot.create(:unit, with_students: false, campus_count: 1, tutorials: 1, stream_count: 0, task_count: 0)
          campus = unit.tutorials.first.campus
          unit.enrol_student(user, campus)
        end
      end
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

    trait :auditor do
      role      { Role.auditor }
    end

  end
end
