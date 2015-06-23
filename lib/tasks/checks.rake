namespace :submission do
  desc "Generate PDF files for submissions"

  def logger
    Rails.logger
  end

  #
  # Returns the file that indicates if this rake process is already executing...
  #
  def rake_executing_marker_file
    File.join(Doubtfire::Application.config.student_work_dir, 'rake.checks.running')
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

  #
  # Use MOSS to check for plagiarism and report to students
  #
  task check_plagiarism:  :environment do
    if is_executing?
      puts 'Skip checks -- already executing'
      logger.info 'Skip checks'
    else
      start_executing

      begin
        logger.info 'Starting check plagiarism'

        Unit.where(active: true).each do | u |
          u.check_plagiarism
        end
      ensure
        end_executing
      end
    end
  end

end
