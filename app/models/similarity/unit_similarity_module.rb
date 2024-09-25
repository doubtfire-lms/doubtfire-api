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

        # JPLAG
        run_jplag_on_done_files(td, tasks_dir, tasks_with_files, unit_code)

        # Skip if not due yet
        next if td.due_date > Time.zone.now

        # Skip if no files changed
        next unless tasks_with_files.count > 1 &&
                    (
                      tasks.where('tasks.file_uploaded_at > ?', last_plagarism_scan).select(&:has_pdf).count > 0 ||
                      td.updated_at > last_plagarism_scan ||
                      force
                    )

        # There are new tasks, check these

        logger.debug 'Contacting MOSS for new checks'

        # Create the MossRuby object
        # moss_key = Doubtfire::Application.secrets.secret_key_moss
        # raise "No moss key set. Check ENV['DF_SECRET_KEY_MOSS'] first." if moss_key.nil?
#
        # moss = MossRuby.new(moss_key)
#
        # # Set options  -- the options will already have these default values
        # moss.options[:max_matches] = 7
        # moss.options[:directory_submission] = true
        # moss.options[:show_num_matches] = 500
        # moss.options[:experimental_server] = false
        # moss.options[:comment] = ''
        # moss.options[:language] = type_data[1]
#
        # tmp_path = File.join(Dir.tmpdir, 'doubtfire', "check-#{id}-#{td.id}")
#
        # begin
        #   # Create a file hash, with the files to be processed
        #   to_check = MossRuby.empty_file_hash
        #   add_done_files_for_plagiarism_check_of(td, tmp_path, to_check, tasks_with_files)
#
        #   FileUtils.chdir(tmp_path)
#
        #   # Get server to process files
        #   logger.debug 'Sending to MOSS...'
        #   url = moss.check(to_check, ->(_) { print '.' })
#
        #   logger.info "MOSS check for #{code} #{td.abbreviation} url: #{url}"
#
        #   td.plagiarism_report_url = url
        #   td.plagiarism_updated = true
        #   td.save
        # rescue StandardError => e
        #   logger.error "Failed to check plagiarism for task #{td.name} (id=#{td.id}). Error: #{e.message}"
        # ensure
        #   FileUtils.chdir(pwd)
        #   FileUtils.rm_rf tmp_path
        # end
      end
      self.last_plagarism_scan = Time.zone.now
      save!
    ensure
      FileUtils.chdir(pwd) if FileUtils.pwd != pwd
    end

    self
  end

  def update_plagiarism_stats
    moss_key = Doubtfire::Application.secrets.secret_key_moss
    raise "No moss key set. Check ENV['DF_SECRET_KEY_MOSS'] first." if moss_key.nil?

    moss = MossRuby.new(moss_key)

    task_definitions.where(plagiarism_updated: true).find_each do |td|
      td.plagiarism_updated = false
      td.save

      # Get results
      url = td.plagiarism_report_url
      logger.debug "Processing MOSS results #{url}"

      warn_pct = td.plagiarism_warn_pct || 50

      results = moss.extract_results(url, warn_pct, ->(line) { puts line })

      # Use results
      results.each do |match|
        task_id1 = %r{.*/(\d+)/$}.match(match[0][:filename])[1]
        task_id2 = %r{.*/(\d+)/$}.match(match[1][:filename])[1]

        t1 = Task.find(task_id1)
        t2 = Task.find(task_id2)

        if t1.nil? || t2.nil?
          logger.error "Could not find tasks #{task_id1} or #{task_id2} for plagiarism stats check!"
          next
        end

        if td.group_set # its a group task
          g1_tasks = t1.group_submission.tasks
          g2_tasks = t2.group_submission.tasks

          g1_tasks.each do |gt1|
            g2_tasks.each do |gt2|
              create_plagiarism_link(gt1, gt2, match, warn_pct)
            end
          end

        else # just link the individuals...
          create_plagiarism_link(t1, t2, match, warn_pct)
        end
      end
    end

    self.last_plagarism_scan = Time.zone.now
    save!

    self
  end

  private

  def create_plagiarism_link(task1, task2, match, warn_pct)
    plk1 = MossTaskSimilarity.where(task_id: task1.id, other_task_id: task2.id).first
    plk2 = MossTaskSimilarity.where(task_id: task2.id, other_task_id: task1.id).first

    if plk1.nil? || plk2.nil?
      # Delete old links between tasks
      plk1&.destroy ## will delete its pair
      plk2&.destroy

      plk1 = MossTaskSimilarity.create do |plm|
        plm.task = task1
        plm.other_task = task2
        plm.pct = match[0][:pct]
        plm.flagged = plm.pct >= warn_pct
      end

      plk2 = MossTaskSimilarity.create do |plm|
        plm.task = task2
        plm.other_task = task1
        plm.pct = match[1][:pct]
        plm.flagged = plm.pct >= warn_pct
      end
    else
      # puts "#{plk1.pct} != #{match[0][:pct]}, #{plk1.pct != match[0][:pct]}"

      # Flag is larger than warn pct and larger than previous pct
      plk1.flagged = match[0][:pct] >= warn_pct && match[0][:pct] >= plk1.pct
      plk2.flagged = match[1][:pct] >= warn_pct && match[1][:pct] >= plk2.pct

      plk1.pct = match[0][:pct]
      plk2.pct = match[1][:pct]
    end

    plk1.plagiarism_report_url = match[0][:url]
    plk2.plagiarism_report_url = match[1][:url]

    plk1.save!
    plk2.save!

    FileHelper.save_plagiarism_html(plk1, match[0][:html])
    FileHelper.save_plagiarism_html(plk2, match[1][:html])
  end

  #
  # Extract all done files related to a task definition matching a pattern into a given directory.
  # Returns an array of files
  #
  def add_done_files_for_plagiarism_check_of(task_definition, tmp_path, to_check, tasks_with_files)
    # get each code file for each task
    task_definition.upload_requirements.each_with_index do |upreq, idx|
      # only check code files marked for similarity checks
      next unless upreq['type'] == 'code' && upreq['tii_check']

      pattern = task_definition.glob_for_upload_requirement(idx)

      tasks_with_files.each do |t|
        t.extract_file_from_done(tmp_path, pattern, ->(_task, to_path, name) { File.join(to_path.to_s, t.student.username.to_s, name.to_s) })
      end

      # extract files matching each pattern
      # -- each pattern
      MossRuby.add_file(to_check, "**/#{pattern}")
    end

    self
  end

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
end
