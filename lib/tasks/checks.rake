namespace :submission do
  desc 'Check active units for task plagiarism'

  def logger
    Rails.logger
  end

  #
  # Returns the file that indicates if this rake process is already executing...
  #
  def rake_plagiarism_executing_marker_file
    File.join(Doubtfire::Application.config.student_work_dir, 'rake.plagiarism.running')
  end

  def is_executing_plagiarism?
    tmp_file = rake_plagiarism_executing_marker_file
    File.exist?(tmp_file)
  end

  def start_executing_plagiarism
    FileUtils.touch(rake_plagiarism_executing_marker_file)
  end

  def end_executing_plagiarism
    FileUtils.rm(rake_plagiarism_executing_marker_file)
  end

  task :simulate_plagiarism, [:num_links] => [:skip_prod, :environment] do |t, args|
    if is_executing_plagiarism?
      puts 'Skip plagiarism check -- already executing'
      logger.info 'Skip plagiarism check -- already executing'
    else
      match_template = {
        url: 'http://moss.stanford.edu/results/375180531/match0-top.html',
        pct: Random.rand(70..100),
        html: File.read('test_files/link_template.html')
      }
      match = [match_template, match_template]
      # Give me two random distinct students with the same TD
      unit = Unit.active_units.first
      num_links = (args[:num_links] || 1).to_i
      puts "Simulating #{num_links} plagiarism links for #{unit.code}..."
      num_links.times do
        td = unit.task_definitions.first
        t1 = unit.tasks.where(task_definition: td).sample()
        t2 = unit.tasks.where(task_definition: td).where.not(project_id: t1.project.id).sample()
        if t1.nil? || t2.nil?
          puts "Can't find any tasks to simulate. Have you run submission:simulate_signoff?'"
          return
        end
        puts "Plagiarism link for #{td.abbreviation} between #{t1.project.student.name} (project_id=#{t1.project.id}) <-> #{t2.project.student.name} (project_id=#{t2.project.id}) created!"
        unit.create_plagiarism_link(t1, t2, match)
        unit.create_plagiarism_link(t2, t1, match)
      end
    end
  end

  task check_plagiarism: :environment do
    if is_executing_plagiarism?
      puts 'Skip plagiarism check -- already executing'
      logger.info 'Skip plagiarism check -- already executing'
    else
      start_executing_plagiarism

      begin
        logger.info 'Starting plagiarism check'

        Unit.active_units.each do |unit|
          puts ' ------------------------------------------------------------ '
          puts "  Starting Plagiarism Check for #{unit.name}"
          puts ' ------------------------------------------------------------ '
          unit.check_plagiarism
          unit.update_plagiarism_stats
        end
        puts ' ------------------------------------------------------------ '
        puts ' done.'
      rescue => e
        puts 'Failed with error'
        puts e.message
      ensure
        end_executing_plagiarism
      end
    end
  end
end
