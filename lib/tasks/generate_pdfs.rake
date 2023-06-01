namespace :submission do
  desc 'Generate PDF files for submissions'

  #
  # Returns the file that indicates if this rake process is already executing...
  #
  def rake_executing_marker_file
    File.join(Doubtfire::Application.config.student_work_dir, 'rake.running')
  end

  def is_executing?
    pid_file = rake_executing_marker_file
    return false unless File.exist?(pid_file)

    # Check that the pid matches something running...
    begin
      pid = File.read(pid_file).to_i
      raise Errno::ESRCH if pid == 0

      Process.getpgid(pid)
      true
    rescue Errno::ESRCH
      # clean up old running file
      end_executing
      false
    end
  end

  def start_executing
    pid_file = rake_executing_marker_file
    FileUtils.touch(pid_file)
    File.write(pid_file, Process.pid)
  end

  def end_executing
    FileUtils.rm(rake_executing_marker_file)
  end

  task portfolio_autogen_check: :environment do
    # Portfolio generation automation:
    # Flip compile_portfolio to true for all projects where the following conditions are met:
    # - associated unit is active
    # - current date is after configured automatic generation dates for the associated unit
    # - portfolio compilation has not been requested already
    # - portfolio is still not available
    # Additionally, set the portfolio_auto_generated property to true to indicate this is auto-generated
    Project.joins(:unit)
           .where(units: { active: true })
           .where("units.portfolio_auto_generation_date < ?", Date.today)
           .where(compile_portfolio: false)
           .reject(&:portfolio_available)
           .each do |project|
      project.compile_portfolio = true
      project.portfolio_auto_generated = true
      project.save
    end
  end

  TeachingPeriod.where("start_date < :today && active_until > :today", today: Date.today).each do |teaching_period|
    teaching_period.units.each do |unit|
      unit.projects.each do |project|
        # We have a learning summary but not a portfolio
        if !project.compile_portfolio && !project.portfolio_available && project.learning_summary_report_path.present? && File.exist?(project.learning_summary_report_path) && !project.uses_draft_learning_summary
          puts "Project #{project.id} has a learning summary but no portfolio"
          project.update compile_portfolio: true
          project.create_portfolio
        end
      end
    end
  end

  task generate_pdfs: :environment do
    # Reduce logging verbosity for the generate_pdfs task in production
    logger.level = :warn if Rails.configuration.pdfgen_quiet

    if is_executing?
      logger.error 'Skip generate pdf -- already executing'
      puts 'Skip generate pdf -- already executing'
    else
      start_executing
      my_source = PortfolioEvidence.move_to_pid_folder
      end_executing

      begin
        logger.info "Starting generate pdf - #{Process.pid}"

        PortfolioEvidence.process_new_to_pdf(my_source)

        projects_to_compile = Project.where(compile_portfolio: true)
        projects_to_compile.each do |project|
          begin
            success = project.create_portfolio
          rescue Exception => e
            logger.error "Failed creating portfolio for project #{project.id}!\n#{e.message}"
            puts "Failed creating portfolio for project #{project.id}!\n#{e.message}"
            success = false
          end

          next unless project.student.receive_portfolio_notifications

          logger.info "emailing portfolio notification to #{project.student.name}"

          if success
            PortfolioEvidenceMailer.portfolio_ready(project).deliver_now
          else
            PortfolioEvidenceMailer.portfolio_failed(project).deliver_now
          end
        end
      ensure
        logger.info "Ending generate pdf - #{Process.pid}"
        if Dir.entries(my_source).count == 2 # . and ..
          FileUtils.rmdir my_source
        end
      end
    end
  end

  # Reuben 07.11.14: Rake script for setting all exisiting portfolio production dates

  task set_portfolio_production_date: :environment do
    logger.info 'Setting portfolio production dates'

    Project.where('portfolio_production_date is null').select(&:portfolio_available).each { |p| p.portfolio_production_date = Time.zone.now; p.save }
  end

  task check_task_pdfs: :environment do
    logger.info 'Starting check of PDF tasks'

    Unit.where('active').each do |u|
      u.tasks.where('portfolio_evidence is not NULL').each do |t|
        unless FileHelper.pdf_valid?(t.portfolio_evidence_path)
          puts t.portfolio_evidence_path
        end
      end
    end
  end
end
