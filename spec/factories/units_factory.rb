# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do

  factory :tutorial do
    meeting_day       "Monday"
    meeting_time      "17:30"
    meeting_location  "ATC101"
    sequence(:abbreviation) { |n| "LA1-#{n}" }
    unit
  end

  factory :task_definition do
    unit
    name                      { Populator.words(1..3) }
    sequence(:abbreviation)   { |n| "P01.#{n}" }
    weighting                 { rand(1..5) }
    target_date               { rand(1..12).weeks.from_now }
    target_grade              { rand(0..4) }
  end

  factory :unit do
    ignore do
      student_count 5
    end

    name          "A"
    description   "Description"
    start_date    DateTime.now
    end_date      DateTime.now + 14.weeks
    code          "COS10001"
    active        true

    after(:create) do | unit, eval |
      create_list(:tutorial, 2, unit: unit)
      create_list(:task_definition, 2, unit: unit)

      # unit.employ_staff( FactoryGirl.create(:user, :convenor), Role.convenor)
      eval.student_count.times do |i|
       unit.enrol_student( FactoryGirl.create(:user, :student), unit.tutorials[i % unit.tutorials.count])
      end
    end
  end
end
