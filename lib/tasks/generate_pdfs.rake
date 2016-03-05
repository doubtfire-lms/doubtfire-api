namespace :submission do
  desc "Generate PDF files for submissions"

  #
  # Returns the file that indicates if this rake process is already executing...
  #
  def rake_executing_marker_file
    File.join(Doubtfire::Application.config.student_work_dir, 'rake.running')
  end

  def is_executing?
    tmp_file = rake_executing_marker_file
    File.exist?(tmp_file)
  end

  def start_executing
    FileUtils.touch(rake_executing_marker_file)
  end

  def end_executing
    FileUtils.rm(rake_executing_marker_file)
  end

  task generate_pdfs:  :environment do
    if is_executing?
      puts 'Skip generate pdf -- already executing'
      logger.info 'Skip generate pdf'
    else
      start_executing

      begin
        logger.info 'Starting generate pdf'

      	PortfolioEvidence.process_new_to_pdf

      	projects_to_compile = Project.where(compile_portfolio: true)
      	projects_to_compile.each do | project |
    		  begin
    	 		  success = project.create_portfolio()
          rescue Exception => e
            logger.error "Failed creating portfolio for project #{project.id}!\n#{e.message}"
            puts "Failed creating portfolio for project #{project.id}!\n#{e.message}"
            success = false
          end

          if project.student.receive_portfolio_notifications
            logger.info "emailing portfolio notification to #{project.student.name}"

            if success
              PortfolioEvidenceMailer.portfolio_ready(project).deliver
            else
              PortfolioEvidenceMailer.portfolio_failed(project).deliver
            end
          end
        end
      ensure
        logger.info 'Ending generate pdf'
        end_executing
      end
    end
  end

  # Reuben 07.11.14: Rake script for setting all exisiting portfolio production dates

  task set_portfolio_production_date:  :environment do
    logger.info 'Setting portfolio production dates'
      
    Project.where("portfolio_production_date is null").select{|p| p.portfolio_available}.each{|p| p.portfolio_production_date = DateTime.now;p.save}
  end

  task check_task_pdfs: :environment do
    logger.info 'Starting check of PDF tasks'

    Unit.where('active').each do |u|
      u.tasks.where('portfolio_evidence is not NULL').each do |t|
        if not FileHelper.pdf_valid?(t.portfolio_evidence)
          puts t.portfolio_evidence
        end
      end
    end
  end
end
