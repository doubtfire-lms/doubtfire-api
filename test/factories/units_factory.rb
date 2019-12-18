# Read about factories at https://github.com/thoughtbot/factory_bot

FactoryBot.define do

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
    sequence(:abbreviation)   { |n| "P1.#{n}" }
    weighting                 { rand(1..5) }
    start_date                { unit.start_date + rand(1..12).weeks }
    target_date               { start_date + rand(1..2).weeks }
    target_grade              { rand(0..3) }
  end

  factory :learning_outcome do
    unit
    name                      { Populator.words(1..3) }
    sequence(:abbreviation)   { |n| "ULO-#{n}" }
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
      group_tasks [ ] #[ {idx: 0, gs: gs }] - index of task, and index of group set
      outcome_count 2
    end

    name            { Populator.words(1..2) }
    description     "Description"
    start_date      Time.zone.now
    end_date        Time.zone.now + 14.weeks
    teaching_period nil
    code            "COS10001"
    active          true

    after(:create) do | unit, eval |
      create_list(:tutorial, eval.tutorials, unit: unit)
      create_list(:task_definition, eval.task_count, unit: unit)
      create_list(:group_set, eval.group_sets, unit: unit)
      create_list(:learning_outcome, eval.outcome_count, unit: unit)

      unit.employ_staff( FactoryBot.create(:user, :convenor), Role.convenor)
      eval.student_count.times do |i|
        unit.enrol_student( FactoryBot.create(:user, :student), unit.tutorials[i % unit.tutorials.count])
      end

      stud = 0
      eval.groups.each do |group_details|
        gs = unit.group_sets[group_details[:gs]]
        grp = FactoryBot.create(:group, group_set: gs)
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
