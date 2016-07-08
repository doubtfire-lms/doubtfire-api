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

  factory :learning_outcome do
    unit
    name                      { Populator.words(1..3) }
    sequence(:ilo_number)     { |n| n }
    description               { "description" }
  end

  factory :unit do
    transient do
      student_count 0
      task_count 2
      tutorials 1
      group_sets 0
      groups [ ] #[ { gs: 0, students:0 } ]
      group_tasks [ ]
      outcome_count 2
    end

    name          "A"
    description   "Description"
    start_date    DateTime.now
    end_date      DateTime.now + 14.weeks
    code          "COS10001"
    active        true

    after(:create) do | unit, eval |
      create_list(:tutorial, eval.tutorials, unit: unit)
      create_list(:task_definition, eval.task_count, unit: unit)
      create_list(:group_set, eval.group_sets, unit: unit)
      create_list(:learning_outcome, eval.outcome_count, unit: unit)

      unit.employ_staff( FactoryGirl.create(:user, :convenor), Role.convenor)
      eval.student_count.times do |i|
       unit.enrol_student( FactoryGirl.create(:user, :student), unit.tutorials[i % unit.tutorials.count])
      end

      stud = 0
      eval.groups.each do |group_details|
        gs = unit.group_sets[group_details[:gs]]
        grp = FactoryGirl.create(:group, group_set: gs)
        group_details[:students].times do
          grp.add_member unit.projects[stud % eval.student_count]
          stud += 1
        end
      end

      eval.group_tasks.each do |task_details|
        td = unit.task_definitions[task_details[:idx]]
        td.group_set = unit.group_sets[task_details[:gs]]
        # puts "Group task #{td.abbreviation} #{td.group_set}"
        td.save
      end
    end
  end
end
