namespace :submission do
  desc "Check active units for task plagiarism"

  def logger
    Rails.logger
  end

  #
  # Returns the file that indicates if this rake process is already executing...
  #
  def rake_executing_marker_file
    File.join(Doubtfire::Application.config.student_work_dir, 'rake.plagiarism.running')
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

  task check_plagiarism:  :environment do
    if is_executing?
      puts 'Skip plagiarism check -- already executing'
      logger.info 'Skip plagiarism check -- already executing'
    else
      start_executing

      begin
        logger.info 'Starting plagiarism check'

        active_units = Unit.where(active: true)

        active_units.each do | unit |
          puts " ------------------------------------------------------------ "
          puts "  Starting Plagiarism Check for #{unit.name}"
          puts " ------------------------------------------------------------ "
          unit.check_plagiarism
          unit.update_plagiarism_stats
        end
        puts " ------------------------------------------------------------ "
        puts " done."
      rescue => e
        puts "Failed with error"
        puts "#{e.message}"
      ensure
        end_executing
      end
    end
  end
end
