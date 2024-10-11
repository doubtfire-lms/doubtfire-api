# freeze_string_literal: true

# Provide moss and tii similarity features in unit class
module UnitSimilarityModule
  #
  # Last date/time of scan
  #
  def last_plagarism_scan
    if self[:last_plagarism_scan].nil?
      DateTime.new(2000, 1, 1)
    else
      self[:last_plagarism_scan]
    end
  end

  # Pass tasks on to plagarism detection software and setup links between students
  def check_similarity(force: false)
    # Get each task...
    return unless active

    # need pwd to restore after cding into submission folder (so the files do not have full path)
    pwd = FileUtils.pwd

    # making temp directory for unit - jplag
    root_work_dir = Rails.root.join("tmp", "jplag", "#{code}-#{id}")
    unit_code = "#{code}-#{id}"
    FileUtils.mkdir_p(root_work_dir)

    begin
      logger.info "Checking plagiarsm for unit #{code} - #{name} (id=#{id})"

      task_definitions.each do |td|
        # making temp directory for each task - jplag
        tasks_dir = root_work_dir.join(td.id.to_s)
        FileUtils.mkdir_p(tasks_dir)

        next if td.jplag_language.nil? || td.upload_requirements.nil? || td.upload_requirements.select { |upreq| upreq['type'] == 'code' && upreq['tii_check'] }.empty?

        # Is there anything to check?
        logger.debug "Checking plagiarism for #{td.name} (id=#{td.id})"
        tasks = tasks_for_definition(td)
        tasks_with_files = tasks.select(&:has_pdf)

        run_jplag_on_done_files(td, tasks_dir, tasks_with_files, unit_code)
        report_path = "#{Doubtfire::Application.config.jplag_report_dir}/#{unit_code}/#{td.id}-result.zip"
        warn_pct = td.plagiarism_warn_pct || 50
        puts "Warn PCT: #{warn_pct}"
        process_jplag_plagiarism_report(report_path, warn_pct, td.group_set)

        # Skip if not due yet
        # TODO: Re-enable this after testing
        # next if td.due_date > Time.zone.now

        # Skip if no files changed
        next unless tasks_with_files.count > 1 &&
                    (
                      tasks.where('tasks.file_uploaded_at > ?', last_plagarism_scan).select(&:has_pdf).count > 0 ||
                      td.updated_at > last_plagarism_scan ||
                      force
                    )

        # There are new tasks, check these with JPLAG
      end
      self.last_plagarism_scan = Time.zone.now
      save!
    ensure
      FileUtils.chdir(pwd) if FileUtils.pwd != pwd
    end

    self
  end

  private

  # Extract all done files related to a task definition matching a pattern into a given directory.
  # Returns an array of files
  # def add_done_files_for_plagiarism_check_of(task_definition, tmp_path, tasks_with_files)
  #   # get each code file for each task
  #   task_definition.upload_requirements.each_with_index do |upreq, idx|
  #     # only check code files marked for similarity checks
  #     next unless upreq['type'] == 'code' && upreq['tii_check']
#
  #     pattern = task_definition.glob_for_upload_requirement(idx)
#
  #     tasks_with_files.each do |t|
  #       t.extract_file_from_done(tmp_path, pattern, ->(_task, to_path, name) { File.join(to_path.to_s, t.student.username.to_s, name.to_s) })
  #     end
  #   end
#
  #   self
  # end

  # JPLAG Function - extracts "done" files for each task and packages them into a directory for JPLAG to run on
  def run_jplag_on_done_files(task_definition, tasks_dir, tasks_with_files, unit_code)
    similarity_pct = task_definition.plagiarism_warn_pct
    return if similarity_pct.nil?

    # Check if the directory exists and create it if it doesn't
    results_dir = "/jplag/results/#{unit_code}"
    `docker exec jplag sh -c 'if [ ! -d "#{results_dir}" ]; then mkdir -p "#{results_dir}"; fi'`

    # Remove existing result file if it exists
    result_file = "#{results_dir}/#{task_definition.id}-result.zip"
    `docker exec jplag sh -c 'if [ -f "#{result_file}" ]; then rm "#{result_file}"; fi'`

    # get each code file for each task
    task_definition.upload_requirements.each_with_index do |upreq, idx|
      # only check code files marked for similarity checks
      next unless upreq['type'] == 'code' && upreq['tii_check']

      pattern = task_definition.glob_for_upload_requirement(idx)

      tasks_with_files.each do |t|
        t.extract_file_from_done(tasks_dir, pattern, ->(_task, to_path, name) { File.join(to_path.to_s, t.student.username.to_s, name.to_s) })
      end

      logger.info "Starting JPLAG container to run on #{tasks_dir}"
      root_dir = Rails.root.to_s
      tasks_dir_split = tasks_dir.to_s.split(root_dir)[1]
      file_lang = task_definition.jplag_language.to_s

      # Run JPLAG on the extracted files
      `docker exec jplag java -jar /jplag/myJplag.jar #{tasks_dir_split} -l #{file_lang} --similarity-threshold=#{similarity_pct} -M RUN -r #{results_dir}/#{task_definition.id}-result`
    end

    # Delete the extracted code files from tmp
    tmp_dir = Rails.root.join("tmp", "jplag")
    logger.info "Deleting files in: #{tmp_dir}"
    logger.info "Files to delete: #{Dir.glob("#{tmp_dir}/*")}"
    FileUtils.rm_rf(Dir.glob("#{tmp_dir}/*"))
    self
  end

  def process_jplag_plagiarism_report(path, warn_pct, is_group)
    # Extract overview json from report zip
    Zip::File.open(path) do |zip_file|
      overview_entry = zip_file.find_entry('overview.json')

      if overview_entry
        # Read the contents of overview.json
        overview_content = overview_entry.get_input_stream.read

        # Parse the JSON into a Ruby hash
        overview_data = JSON.parse(overview_content)

        # Iterate over the "top_comparisons" array and collect the required fields
        top_comparisons = overview_data['top_comparisons'].map do |comparison|
          {
            first_submission: comparison['first_submission'],
            second_submission: comparison['second_submission'],
            max_similarity: comparison['similarities']['MAX'] * 100
          }
        end

        # Save the results to the database
        top_comparisons.each do |comparison|
          task1_id = nil
          task2_id = nil
          zip_file.each do |entry|
            if entry.name =~ %r{\Afiles/#{comparison[:first_submission]}/}
              task1_id = entry.name.split('/')[2].to_i
            elsif entry.name =~ %r{\Afiles/#{comparison[:second_submission]}/}
              task2_id = entry.name.split('/')[2].to_i
            end
          end
          first_submission = Task.find(task1_id) if task1_id
          second_submission = Task.find(task2_id) if task2_id

          if first_submission.nil? || second_submission.nil?
            logger.error "Could not find tasks #{comparison[:first_submission]} or #{comparison[:second_submission]} for plagiarism stats check!"
            next
          end

          if is_group # its a group task
            g1_tasks = first_submission.group_submission.tasks
            g2_tasks = second_submission.group_submission.tasks
            g1_tasks.each do |gt1|
              g2_tasks.each do |gt2|
                next if gt1.student == gt2.student
                create_plagiarism_link(gt1, gt2, warn_pct, comparison[:max_similarity])
              end
            end
          else # just link the individuals...
            create_plagiarism_link(first_submission, second_submission, warn_pct, comparison[:max_similarity])
          end
        end
      else
        puts 'overview.json not found in the zip file'
      end

      self
    end
  end

  def create_plagiarism_link(task1, task2, warn_pct, max_similarity)
    # Create a new plagiarism link between the two tasks
    plk1 = JplagTaskSimilarity.where(task_id: task1.id, other_task_id: task2.id).first
    plk2 = JplagTaskSimilarity.where(task_id: task2.id, other_task_id: task1.id).first
    if plk1.nil? || plk2.nil?
      # Delete old links between tasks
      plk1&.destroy ## will delete its pair
      plk2&.destroy
      plk1 = JplagTaskSimilarity.create do |plm|
        plm.task = task1
        plm.other_task = task2
        plm.pct = max_similarity
        plm.flagged = plm.pct >= warn_pct
      end
      plk2 = JplagTaskSimilarity.create do |plm|
        plm.task = task2
        plm.other_task = task1
        plm.pct = max_similarity
        plm.flagged = plm.pct >= warn_pct
      end
    else
      # Flag is larger than warn pct and larger than previous pct
      plk1.flagged = max_similarity >= warn_pct && max_similarity >= plk1.pct
      plk2.flagged = max_similarity >= warn_pct && max_similarity >= plk2.pct
      plk1.pct = max_similarity
      plk2.pct = max_similarity
    end
    plk1.save!
    plk2.save!
  end
end
