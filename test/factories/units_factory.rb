# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do

  factory :task_definition do
    unit
    name                      { Populator.words(1..3) }
    description               { Populator.words(1..3) }
    upload_requirements       { [{'key' => 'file0','name' => 'Imported Code','type' => 'code'}] }
    sequence(:abbreviation)   { |n| "P1.#{n}" }
    weighting                 { rand(1..5) }
    start_date                { unit.start_date + rand(1..12).weeks }
    target_date               { start_date + rand(1..2).weeks }
    target_grade              { rand(0..3) }
    group_set                 nil
    tutorial_stream           { unit.tutorial_streams.sample }
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
      unenrolled_student_count 0
      task_count 2
      tutorials 1  #per campus
      tutorial_config [] #[ {stream: 0, campus: 0} ]
      group_sets 0
      groups [ ] #[ { gs: 0, students:0 } ]
      group_tasks [ ] #[ {idx: 0, gs: 0 }] - index of task, and index of group set
      outcome_count 2
      stream_count 0
      campus_count 1
      set_one_of_each_task false  # In addition to the standard tasks, also add one of each different think of task - group, quality, graded, etc.
    end

    name            { Populator.words(1..2) }
    description     "Description"
    start_date      Time.zone.now
    end_date        Time.zone.now + 14.weeks
    teaching_period nil
    code            "COS10001"
    active          true

    after(:create) do | unit, eval |
      group_sets = eval.group_sets
      task_count = eval.task_count
      group_tasks = eval.group_tasks.clone
      groups = eval.groups.clone

      if eval.set_one_of_each_task
        group_sets = 1 unless group_sets > 0
        task_count = 3 if task_count < 3
        group_tasks << {idx: 0, gs: group_sets - 1}
        group_sets.times do |gs|
          (eval.student_count / 4).times do
            groups << { gs: gs, students: 4}
          end
        end
      end

      campuses = create_list(:campus, eval.campus_count)

      create_list(:group_set, group_sets, unit: unit)
      create_list(:learning_outcome, eval.outcome_count, unit: unit)
      tutorial_streams = create_list(:tutorial_stream, eval.stream_count, unit: unit)
      create_list(:task_definition, task_count, unit: unit)

      if eval.set_one_of_each_task
        unit.task_definitions[1].update(max_quality_pts: 5)
        unit.task_definitions[2].update(is_graded: true)
      end

      campuses.each do |c|
        # loop to 2nd last, unless there are no streams... then loop for all
        break if (c == campuses.last) && tutorial_streams.count > 0

        if tutorial_streams.count > 0
          tutorial_streams.each { |ts| create_list(:tutorial, eval.tutorials, unit: unit, campus: c, tutorial_stream: ts ) }
        else
          create_list(:tutorial, eval.tutorials, unit: unit, campus: c )
        end
      end

      # Now update last campus - give it tutorials with no tutorial streams to mimic "cloud"
      if tutorial_streams.count > 0
        create_list(:tutorial, eval.tutorials, unit: unit, campus: campuses.last )
      end

      unit.employ_staff( FactoryGirl.create(:user, :convenor), Role.convenor)

      campuses.each do |c|
        (eval.unenrolled_student_count + eval.student_count).times do |i|
          p = unit.enrol_student( FactoryGirl.create(:user, :student), c )
          next if i < eval.unenrolled_student_count

          if c.tutorials.first.tutorial_stream.present?
            tutorial_streams.each do |ts|
              p.enrol_in ts.tutorials.where(campus_id: c.id).sample
            end
          else
            p.enrol_in c.tutorials[i % c.tutorials.count]
          end
        end
      end

      stud = 0
      groups.each do |group_details|
        gs = unit.group_sets[group_details[:gs]]
        grp = FactoryGirl.create(:group, group_set: gs)
        group_details[:students].times do
          grp.add_member unit.projects[stud % eval.student_count]
          stud += 1
        end
      end

      group_tasks.each do |task_details|
        td = unit.task_definitions[task_details[:idx]]
        td.group_set = unit.group_sets[task_details[:gs]]
        # puts "Group task #{td.abbreviation} #{td.group_set} = #{td.is_group_task?} #{td.valid?}"
        td.save!
      end
    end
  end
end
