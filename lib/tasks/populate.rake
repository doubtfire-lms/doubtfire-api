require_all 'lib/helpers'
namespace :db do
  desc 'Mark off some of the due tasks'
  task expand_first_unit: [:skip_prod, :environment] do
    unit = Unit.first
    tutes = unit.tutorials
    for student_count in 0..2000
      student = find_or_create_student("student_#{student_count}")
      proj = unit.enrol_student(student, tutes[student_count % tutes.count])
    end
  end

  desc 'Mark off some of the due tasks'
  task simulate_signoff: [:skip_prod, :environment] do
    Unit.all.each do |unit|
      current_week = ((Time.zone.now - unit.start_date) / 1.week).floor

      unit.students.each do |proj|
        #
        # Get the student project
        #
        p = Project.find(proj.id)
        p.tasks.destroy_all

        # Determine who is assessing their work...
        tutor = p.main_tutor

        p.target_grade = rand(0..3)

        case rand(1..100)
        when 0..5
          kept_up_to_week = current_week + rand(1..4)
          p.target_grade = rand(2..3)
        when 6..10
          kept_up_to_week = current_week + 1
          p.target_grade = rand(1..3)
        when 11..40
          kept_up_to_week = current_week
        when 41..60
          kept_up_to_week = current_week - 1
          kept_up_to_week = 1 unless kept_up_to_week > 0
        when 61..70
          kept_up_to_week = current_week - rand(1..4)
          kept_up_to_week = 1 unless kept_up_to_week > 0
        when 71..80
          kept_up_to_week = current_week - rand(3..10)
          kept_up_to_week = 1 unless kept_up_to_week > 0
        when 81..90
          kept_up_to_week = current_week - rand(3..10)
          kept_up_to_week = 0 unless kept_up_to_week > 0
        else
          kept_up_to_week = 0
          p.target_grade = 0
        end

        p.save

        kept_up_to_date = unit.date_for_week_and_day(kept_up_to_week, 'Fri')

        assigned_task_defs = p.assigned_task_defs.where('target_date <= :up_to_date', up_to_date: kept_up_to_date)

        time_to_complete_task = (kept_up_to_date - (unit.start_date + 1.week)) / assigned_task_defs.count

        i = 0
        assigned_task_defs.order('target_date').each do |at|
          task = p.task_for_task_definition(at)
          # if its more than three week past kept up to date...
          if kept_up_to_date >= task.target_date + 2.weeks
            complete_date = unit.start_date + i * time_to_complete_task + rand(7..14).days
            if complete_date < unit.start_date + 1.week
              complete_date = unit.start_date + 1.week
            elsif complete_date > Time.zone.now
              complete_date = Time.zone.now
            end
            task.assess TaskStatus.complete, tutor, complete_date
          elsif kept_up_to_date >= task.target_date + 1.week
            complete_date = unit.start_date + i * time_to_complete_task + rand(7..14).days
            if complete_date < unit.start_date + 1.week
              complete_date = unit.start_date + 1.week
            elsif complete_date > Time.zone.now
              complete_date = Time.zone.now
            end

            # 1 to 3
            case rand(1..100)
            when 0..50
              task.assess TaskStatus.complete, tutor, complete_date
            when 51..75
              task.assess TaskStatus.discuss, tutor, complete_date
            when 76..90
              task.assess TaskStatus.demonstrate, tutor, complete_date
            when 91..95
              task.assess TaskStatus.fix_and_resubmit, tutor, complete_date
            when 96..97
              task.assess TaskStatus.working_on_it, tutor, complete_date
            when 97
              task.assess TaskStatus.do_not_resubmit, tutor, complete_date
            when 98..99
              task.assess TaskStatus.redo, tutor, complete_date
            else
              task.submit complete_date
            end
          else
            complete_date = unit.start_date + i * time_to_complete_task + rand(7..10).days
            if complete_date < unit.start_date + 1.week
              complete_date = unit.start_date + 1.week
            elsif complete_date > Time.zone.now
              complete_date = Time.zone.now
            end

            # 1 to 3
            case rand(1..100)
            when 0..3
              task.assess TaskStatus.complete, tutor, complete_date
            when 4..60
              task.submit complete_date
            when 61..70
              task.assess TaskStatus.discuss, tutor, complete_date
            when 71..80
              task.assess TaskStatus.demonstrate, tutor, complete_date
            when 81..90
              task.assess TaskStatus.fix_and_resubmit, tutor, complete_date
            when 91..98
              task.assess TaskStatus.working_on_it, tutor, complete_date
            when 99
              task.assess TaskStatus.redo, tutor, complete_date
            else
              task.submit complete_date
            end
          end

          i += 1
          pdf_path = task.final_pdf_path
          if pdf_path
            FileUtils.ln_s(Rails.root.join('test_files', 'unit_files', 'sample-student-submission.pdf'), pdf_path)
          end
        end

        next_assigned_tasks = p.assigned_tasks.where('target_date > :up_to_date AND target_date <= :next_week', up_to_date: kept_up_to_date, next_week: kept_up_to_date + 1.week)

        next_assigned_tasks.each do |at|
          task = p.task_for_task_definition(at)
          # 1 to 3
          case rand(1..100)
          when 0..60
            task.assess tatus.working_on_it, tutor, Time.zone.now
          when 60..75
            task.assess TaskStatus.need_help, tutor, Time.zone.now
            
            pdf_path = task.final_pdf_path
            if pdf_path
              FileUtils.ln_s(Rails.root.join('test_files', 'unit_files', 'sample-student-submission.pdf'), pdf_path)
            end
          end
        end

        p.save
      end
    end
  end

  desc 'Clear the database and fill with test data'
  task populate: [:skip_prod, :setup, :migrate] do
    scale = ENV['SCALE'] ? ENV['SCALE'].to_sym : :small
    extended = ENV['EXTENDED'] == 'true'

    dbpop = DatabasePopulator.new scale
    dbpop.generate_fixed_data
    dbpop.generate_users
    dbpop.generate_units

    # Run simulate signoff?
    unless extended
      puts '-> Would you like to simulate student progress? This may take a while... [y/n]'
    end
    if extended || STDIN.gets.chomp.casecmp('y').zero?
      puts '-> Simulating signoff...'
      Rake::Task['db:simulate_signoff'].execute
    end
    puts '-> Done.'
  end
end
