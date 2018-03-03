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

  def assess_task(current_user, task, tutor, status, complete_date)
    alignments = []
    sum_ratings = 0
    task.unit.learning_outcomes.each do |lo|
      data = {
        ilo_id: lo.id,
        rating: rand(0..5),
        rationale: "Simulated rationale text..."
      }
      sum_ratings += data[:rating]
      alignments << data
    end

    if task.group_task?
      raise "Cant support group tasks yet in simulation :("
    end
    contributions = nil
    trigger = 

    task.create_alignments_from_submission(alignments) unless alignments.nil?
    task.create_submission_and_trigger_state_change(current_user) #, propagate = true, contributions = contributions, trigger = trigger)
    task.assess status, tutor, complete_date

    pdf_path = task.final_pdf_path
    if pdf_path
      FileUtils.ln_s(Rails.root.join('test_files', 'unit_files', 'sample-student-submission.pdf'), pdf_path)
    end

    task.portfolio_evidence = pdf_path
    task.save
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
        p.remove_portfolio

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
            assess_task(proj, task, tutor, TaskStatus.complete, complete_date)
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
              assess_task(proj, task, tutor, TaskStatus.complete, complete_date)
            when 51..75
              assess_task(proj, task, tutor, TaskStatus.discuss, complete_date)
            when 76..90
              assess_task(proj, task, tutor, TaskStatus.demonstrate, complete_date)
            when 91..95
              assess_task(proj, task, tutor, TaskStatus.fix_and_resubmit, complete_date)
            when 96..97
              assess_task(proj, task, tutor, TaskStatus.working_on_it, complete_date)
            when 97
              assess_task(proj, task, tutor, TaskStatus.do_not_resubmit, complete_date)
            when 98..99
              assess_task(proj, task, tutor, TaskStatus.redo, complete_date)
            else
              assess_task(proj, task, tutor, TaskStatus.ready_to_mark, complete_date)
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
              assess_task(proj, task, tutor, TaskStatus.complete, complete_date)
            when 4..60
              assess_task(proj, task, tutor, TaskStatus.ready_to_mark, complete_date)
            when 61..70
              assess_task(proj, task, tutor, TaskStatus.discuss, complete_date)
            when 71..80
              assess_task(proj, task, tutor, TaskStatus.demonstrate, complete_date)
            when 81..90
              assess_task(proj, task, tutor, TaskStatus.fix_and_resubmit, complete_date)
            when 91..98
              assess_task(proj, task, tutor, TaskStatus.working_on_it, complete_date)
            when 99
              assess_task(proj, task, tutor, TaskStatus.redo, complete_date)
            else
              assess_task(proj, task, tutor, TaskStatus.ready_to_mark, complete_date)
            end
          end

          i += 1
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

        if rand(0..99) > 70
          portfolio_tmp_dir = p.portfolio_temp_path
          FileUtils.mkdir_p(portfolio_tmp_dir)

          lsr_path = File.join(portfolio_tmp_dir, "000-document-LearningSummaryReport.pdf")
          FileUtils.ln_s(Rails.root.join('test_files', 'unit_files', 'sample-learning-summary.pdf'), lsr_path) unless File.exists? lsr_path
          p.compile_portfolio = true
          p.create_portfolio
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
