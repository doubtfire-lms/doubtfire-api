namespace :submission do
  desc 'Generate PDF files for submissions'

  #
  # Returns the file that indicates if this rake process is already executing...
  #
  def rake_executing_marker_file
    File.join(Doubtfire::Application.config.student_work_dir, 'rake.running')
  end

  def is_process_running?(pid)
    rreturn false if pid == 0

    Process.getpgid(pid)
    true
  rescue Errno::ESRCH
    false
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

  # Return a list of the directory names for processes that are running or not running
  def old_executing(running)
    # Report old running processes...
    Dir.entries(FileHelper.student_work_dir(:in_process)).select { |entry| entry.start_with?("pid_") }.filter do |entry|
      is_process_running?(entry[4..].to_i) == running
    end
  end

  def should_run?
    # Only run if there are not more than 3 processes running
    max_processes = Rails.configuration.pdfgen_max_processes || 2
    old_executing(true).count < max_processes
  end

  def clean_up_failed_runs
    # Clean up any old failed runs
    old_executing(false).each do |entry|
      puts "Existing process failed... not cleaned up - #{entry}"

      # Move to the failed run folder
      FileHelper.move_files(File.join(FileHelper.student_work_dir(:in_process), entry), FileHelper.student_work_dir(:new), false)
    end
  end

  def end_executing
    FileUtils.rm(rake_executing_marker_file)
  end

  task portfolio_autogen_check: :environment do
    PdfGeneration::ProjectCompilePortfolioModule.projects_awaiting_auto_generation
                                                .each(&:auto_generate_portfolio)
  end

  task create_missing_portfolios: :environment do
    TeachingPeriod.where("start_date < :today && active_until > :today", today: Date.today).each do |teaching_period|
      teaching_period.units.each do |unit|
        unit.projects.each do |project|
          # We have a learning summary but not a portfolio
          next unless !project.compile_portfolio && !project.portfolio_available && project.learning_summary_report_path.present? && File.exist?(project.learning_summary_report_path) && !project.uses_draft_learning_summary

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

    if is_executing? || !should_run?
      logger.error 'Skip generate pdf -- already executing'
      puts 'Skip generate pdf -- already executing'
    else
      start_executing

      # Copy task files
      my_source = PortfolioEvidence.move_to_pid_folder

      # Rescue any projects that were orphaned by a previous process
      Project.where('NOT portfolio_generation_pid IS NULL').group(:portfolio_generation_pid).select('MIN(portfolio_generation_pid) as pid').map { |r| r['pid'] }.each do |pid|
        next if is_process_running?(pid)

        # That process is not running... so pick up portfolios here
        Project.where(portfolio_generation_pid: pid).update_all(portfolio_generation_pid: Process.pid)
      end

      # Secure portfolios
      Project.where(compile_portfolio: true, portfolio_generation_pid: nil)
             .limit(10)
             .update_all(portfolio_generation_pid: Process.pid)

      # Clean up any old failed runs - now after I have the files I need :)
      clean_up_failed_runs

      end_executing

      begin
        logger.info "Starting generate pdf - #{Process.pid}"

        # Compile the tasks
        PortfolioEvidence.process_new_to_pdf(my_source)

        # Now compile the portfolios
        Project.where(compile_portfolio: true, portfolio_generation_pid: Process.pid).each do |project|
          next unless project.portfolio_generation_pid == Process.pid

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
        # Ensure that we clear the pid from the projects so that they can be processed again
        Project.where(portfolio_generation_pid: Process.pid).update_all(portfolio_generation_pid: nil)

        # Remove the processing directory
        if Dir.entries(my_source).count == 2 # . and ..
          FileUtils.rmdir my_source
        end

        logger.info "Ending generate pdf - #{Process.pid}"
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
