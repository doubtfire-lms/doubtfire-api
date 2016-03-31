class Task < ActiveRecord::Base
  include ApplicationHelper
  include LogHelper

  #
  # Permissions around task data
  #
  def self.permissions
    # What can students do with tasks?
    student_role_permissions = [
      :get,
      :put,
      :get_submission,
      :make_submission,
      :delete_own_comment
    ]
    # What can tutors do with tasks?
    tutor_role_permissions = [
      :get,
      :put,
      :get_submission,
      :make_submission,
      :delete_other_comment,
      :delete_own_comment,
      :view_plagiarism
    ]
    # What can convenors do with tasks?
    convenor_role_permissions = [
      :get,
      :get_submission,
      :make_submission,
      :delete_other_comment,
      :delete_own_comment,
      :view_plagiarism
    ]
    # What can nil users do with tasks?
    nil_role_permissions = [

    ]

    # Return permissions hash
    {
      :student  => student_role_permissions,
      :tutor    => tutor_role_permissions,
      :convenor => convenor_role_permissions,
      :nil      => nil_role_permissions
    }
  end

  def role_for(user)
    project_role = project.user_role(user)
    return project_role unless project_role.nil?
    logger.debug "Getting role for user #{user.id}: #{task_definition.abbreviation} #{task_definition.group_set}"
    # check for group member
    if group_task?
      logger.debug "Checking group"
      if group && group.has_user(user)
        return :group_member
      else
        return nil
      end
    end
  end

  # Model associations
  belongs_to :task_definition       # Foreign key
  belongs_to :project               # Foreign key
  belongs_to :task_status           # Foreign key
  belongs_to :group_submission

  has_many :sub_tasks,      dependent: :destroy
  has_many :comments, class_name: "TaskComment", dependent: :destroy, inverse_of: :task
  has_many :plagiarism_match_links, class_name: "PlagiarismMatchLink", dependent: :destroy, inverse_of: :task
  has_many :reverse_plagiarism_match_links, class_name: "PlagiarismMatchLink", dependent: :destroy, inverse_of: :other_task, foreign_key: "other_task_id"
  has_many :learning_outcome_task_links, dependent: :destroy # links to learning outcomes
  has_many :learning_outcomes,  through: :learning_outcome_task_links

  after_save :update_project

  def all_comments
    if group_submission.nil?
      comments
    else
      TaskComment.joins(:task).where("tasks.group_submission_id = :id", id: group_submission.id)
    end
  end

  def self.for_unit(unit_id)
    Task.joins(:project).where("projects.unit_id = :unit_id", unit_id: unit_id)
  end

  def self.for_user(user)
    Task.joins(:project).where("projects.user_id = ?", user.id)
  end

  def unit
    project.unit
  end

  def student
    project.student
  end

  def upload_requirements
    task_definition.upload_requirements
  end

  def processing_pdf
    File.exists? File.join(FileHelper.student_work_dir(:new), "#{id}")
    #portfolio_evidence == nil && ready_to_mark?
  end

  def update_project
    project.update_attribute(:progress, project.calculate_progress)
    project.update_attribute(:status, project.calculate_status)
  end

  def overdue?
    # A task cannot be overdue if it is marked complete
    return false if complete?

    # Compare the recommended date with the date given to determine
    # if the task is overdue
    recommended_date = task_definition.target_date
    project.reference_date > recommended_date && weeks_overdue >= 1
  end

  def long_overdue?
    # A task cannot be overdue if it is marked complete
    return false if complete?

    # Compare the recommended date with the date given to determine
    # if the task is overdue
    recommended_date = task_definition.target_date
    project.reference_date > recommended_date && weeks_overdue > 2
  end

  def currently_due?
    # A task is currently due if it is not complete and over/under the due date by less than
    # 7 days
    !complete? && days_overdue.between?(-7, 7)
  end

  def weeks_until_due
    days_until_due / 7
  end

  def days_until_due
    (task_definition.target_date - project.reference_date).to_i / 1.day
  end

  def weeks_overdue
    days_overdue / 7
  end

  def days_since_completion
    (project.reference_date - completion_date.to_datetime).to_i / 1.day
  end

  def weeks_since_completion
    days_since_completion / 7
  end

  def days_overdue
    (project.reference_date - task_definition.target_date).to_i / 1.day
  end

  def due_date
    task_definition.due_date
  end

  def target_date
    task_definition.target_date
  end

  def complete?
    status == :complete
  end

  def discuss_or_demonstrate?
    status == :discuss || status == :demonstrate
  end

  def discuss?
    status == :discuss
  end

  def demonstrate?
    status == :demonstrate
  end

  def fail?
    status == :fail
  end

  def task_submission_closed?
    complete? || discuss_or_demonstrate? || do_not_resubmit? || fail?
  end

  def ok_to_submit?
    status != :complete && status != :discuss && status != :demonstrate
  end

  def ready_to_mark?
    status == :ready_to_mark
  end

  def ready_or_complete?
    status == :complete || status == :discuss || status == :demonstrate || status == :ready_to_mark
  end

  def fix_and_resubmit?
    status == :fix_and_resubmit
  end

  def do_not_resubmit?
    status == :do_not_resubmit
  end

  def redo?
    status == :redo
  end

  def need_help?
    status == :need_help
  end

  def working_on_it?
    status == :working_on_it
  end

  def status
    task_status.status_key
  end

  def has_pdf
    (not portfolio_evidence.nil?) and File.exists?(portfolio_evidence)
  end

  def assign_evidence_path(final_pdf_path, propagate=true)
    if group_task? and propagate
      group_submission.tasks.each do |task|
        task.assign_evidence_path(final_pdf_path, false)
      end
      reload
    else
      logger.debug "Assigning task #{id} to final PDF evidence path #{final_pdf_path}"
      self.portfolio_evidence = final_pdf_path
      logger.debug "PDF evidence path for task #{id} is now #{self.portfolio_evidence}"
      self.save
    end
  end

  def group_task?
    (not group_submission.nil?) || (not task_definition.group_set.nil?)
  end

  def group
    return nil unless group_task?
    # Cannot use group submission as group may change after submission
    # need to locate group via unit's groups
    project.groups.where(group_set_id: task_definition.group_set_id).first
  end

  def ensured_group_submission
    return nil unless group_task?
    return group_submission unless group_submission.nil?

    group.create_submission self, "", group.projects.map { |proj| { project: proj, pct: 100 / group.projects.count }  }
  end

  def trigger_transition(trigger="", by_user=nil, bulk=false, group_transition=false)
    #
    # Ensure that assessor is allowed to update the task in the indicated way
    #
    role = role_for(by_user)

    return nil if role.nil?

    #
    # Ensure that only staff can change from staff assigned status if
    # this is a restricted task
    #
    return nil if [ :student, :group_member ].include?(role) &&
                  task_definition.restrict_status_updates &&
                  self.task_status.in?(TaskStatus.staff_assigned_statuses)

    # Protect closed states from student changes
    return nil if [ :student, :group_member ].include?(role) && task_submission_closed?

    #
    # State transitions based upon the trigger
    #

    #
    # Tutor and student can trigger these actions...
    #
    case trigger
      when "ready_to_mark", "rtm"
        submit
      when "not_started"
        engage TaskStatus.not_started
      when "not_ready_to_mark"
        engage TaskStatus.not_started
      when "need_help"
        engage TaskStatus.need_help
      when "working_on_it"
        engage TaskStatus.working_on_it
      else
        #
        # Only tutors can perform these actions
        #
        if role == :tutor
          case trigger
            when "fail", 'f'
              assess TaskStatus.fail, by_user
            when "redo"
              assess TaskStatus.redo, by_user
            when "complete"
              assess TaskStatus.complete, by_user
            when "fix_and_resubmit", "fix"
              assess TaskStatus.fix_and_resubmit, by_user
            when "do_not_resubmit", "dnr", "fix_and_include", "fixinc"
              assess TaskStatus.do_not_resubmit, by_user
            when "demonstrate", "de", "demo"
              assess TaskStatus.demonstrate, by_user
            when "discuss", "d"
              assess TaskStatus.discuss, by_user
          end
        end
    end

    # if this is a status change of a group task -- and not already doing group update
    if (not group_transition) && group_task?
      logger.debug "Group task transition for #{group_submission} set to status #{trigger} (id=#{id})"
      if not [ TaskStatus.working_on_it, TaskStatus.need_help  ].include? task_status
        ensured_group_submission.propagate_transition self, trigger, by_user
      end
    end

    if not bulk then project.calc_task_stats(self) end
  end

  #
  # Tries to grade the task if it is a graded task
  #
  def grade_task(new_grade, ui = nil, grading_group = false)
    raise_error = lambda { |message|
      ui.error!({"error" => message}, 403) unless ui.nil?
      raise message
    }

    grade_map = {
      'p'  => 0,
      'c'  => 1,
      'd'  => 2,
      'hd' => 3
    }
    if task_definition.is_graded
      if new_grade.nil?
        raise_error.call("No grade was supplied for a graded task (task id #{self.id})")
      else
        # validate (and convert if need be) new_grade
        unless new_grade.is_a?(String) || new_grade.is_a?(Integer)
          raise_error.call("New grade supplied to task is not a string or integer (task id #{self.id})")
        end
        if new_grade.is_a?(String)
          unless grade_map.keys.include?(new_grade.downcase)
            raise_error.call("New grade supplied to task is not an invalid string - expects one of {p|c|d|hd} (task id #{self.id})")
          else
            # convert string representation to integer representation
            new_grade = grade_map[new_grade]
          end
        end
        unless new_grade.is_a?(Integer) && grade_map.values.include?(new_grade.to_i)
          raise_error.call("New grade supplied to task is not an invalid integer - expects one of {0|1|2|3} (task id #{self.id})")
        end
        # propagate new grade to all OTHER group members
        if group_task? && !grading_group
          logger.debug "Grading a group submission to grade #{new_grade}"
          ensured_group_submission.propagate_grade self, new_grade, ui
        end

        # now update this task... (may be group task or individual...)
        logger.debug "Grading task #{self.id} in a group submission to grade #{new_grade}"
        update(:grade => new_grade)
      end
    elsif grade?
      raise_error.call("Grade was supplied for a non-graded task (task id #{self.id})")
    end
  end

  def assess(task_status, assessor, assess_date = Time.zone.now)
    # Set the task's status to the assessment outcome status
    # and flag it as no longer awaiting signoff
    self.task_status       = task_status

    # Ensure it has a submission date
    if self.submission_date.nil?
      self.submission_date = assess_date
    end

    # Set the assessment date and update the times assessed
    if self.assessment_date.nil? || self.assessment_date < self.submission_date
      # only a new assessment if it was submitted after last assessment
      self.times_assessed += 1
    end
    self.assessment_date  = assess_date

    # Set the completion date of the task if it's been completed
    if ready_or_complete?
      if completion_date.nil?
        self.completion_date = assess_date
      end
    else
      self.completion_date = nil
    end

    # Save the task
    if save!
      # If a task has been completed, that means the project
      # has definitely started
      project.start

      # If the task was given an assessment outcome
      if assessed?
        # Grab the submission for the task if the user made one
        submission = TaskSubmission.where(task_id: id).order(:submission_time).reverse_order.first
        # Prepare the attributes of the submission
        submission_attributes = {task: self, assessment_time: assess_date, assessor: assessor, outcome: task_status.name}

        # Create or update the submission depending on whether one was made
        if submission.nil?
          TaskSubmission.create! submission_attributes
        else
          submission.update_attributes submission_attributes
          submission.save
        end
      end
    end
  end

  def engage(engagement_status)
    self.task_status       = engagement_status

    if save!
      TaskEngagement.create!(task: self, engagement_time: Time.zone.now, engagement: task_status.name)
    end
  end

  def submit(submit_date = Time.zone.now)
    self.task_status      = TaskStatus.ready_to_mark
    self.submission_date  = submit_date

    if save!
      project.start
      submission = TaskSubmission.where(task_id: self.id).order(:submission_time).reverse_order.first

      if submission.nil?
        TaskSubmission.create!(task: self, submission_time: submit_date)
      else
        if !submission.submission_time.nil? && submission.submission_time < 1.hour.since(submit_date)
          submission.submission_time = submit_date
          submission.save!
        else
          TaskSubmission.create!(task: self, submission_time: submit_date)
        end
      end
    end
  end

  def assessed?
    redo? ||
    fix_and_resubmit? ||
    do_not_resubmit? ||
    fail? ||
    complete?
  end

  def weight
    task_definition.weighting.to_f
  end

  def add_comment(user, text)
    text.strip!
    return nil if user.nil? || text.nil? || text.empty?

    lc = comments.last
    return if lc && lc.user == user && lc.comment == text

    ensured_group_submission if group_task?

    comment = TaskComment.create()
    comment.task = self
    comment.user = user
    comment.comment = text
    comment.save!
    comment
  end

  def last_comment()
    all_comments.last
  end

  def last_comment_by(user)
    result = all_comments.where(user: user).last

    return '' if result.nil?
    result.comment
  end

  def has_comment_by(user)
    last_comment_by(user).length > 0
  end

  def is_last_comment_by?(user)
    last_comment = all_comments.last
    return false if last_comment.nil?

    last_comment.user == user
  end

  def last_comment_not_by(user)
    result = all_comments.where("user_id != :id", id: user.id).last

    return '' if result.nil?
    result.comment
  end

  # Indicates what is the largest % similarity is for this task
  def pct_similar
    if plagiarism_match_links.order(pct: :desc).first.nil?
      0
    else
      plagiarism_match_links.order(pct: :desc).first.pct
    end
  end

  def similar_to_count
    plagiarism_match_links.count
  end

  def recalculate_max_similar_pct
    self.max_pct_similar = pct_similar()
    self.save

    project.recalculate_max_similar_pct()
  end

  def name
    task_definition.name
  end

  def student_work_dir(type, create = true)
    if group_task?
      FileHelper.student_group_work_dir(type, group_submission, self, create)
    else
      FileHelper.student_work_dir(type, self, create)
    end
  end

  def zip_file_path_for_done_task()
    if group_task?
      if group_submission.nil?
        nil
      else
        "#{FileHelper.student_group_work_dir(:done, group_submission)[0..-2]}.zip"
      end
    else
      "#{student_work_dir(:done, false)[0..-2]}.zip"
    end
  end

  def extract_file_from_done(to_path, pattern, name_fn)
    zip_file = zip_file_path_for_done_task()
    return false if zip_file.nil? || (not File.exists? zip_file)

    Zip::File.open(zip_file) do |zip|
      # Extract folders
      zip.each do |entry|
        # Extract to file/directory/symlink
        logger.debug "Extracting file from done: #{entry.name}"
        if entry.name_is_directory?
          entry.extract( name_fn.call(self, to_path, entry.name) )  { true }
        end
      end
      zip.glob("**/#{pattern}").each do |entry|
        entry.extract( name_fn.call(self, to_path, entry.name) ) { true }
      end
    end
  end

  #
  # Compress the done files for a student - includes cover page and work uploaded
  #
  def compress_new_to_done()
    task_dir = student_work_dir(:new, false)
    zip_file = zip_file_path_for_done_task()
    return if zip_file.nil? || (not Dir.exists? task_dir)

    FileUtils.rm(zip_file) if File.exists? zip_file

    #compress image files
    image_files = Dir.entries(task_dir).select { | f | (f =~ /^\d{3}.(image)/) == 0 }
    image_files.each do |img|
      FileHelper.compress_image "#{task_dir}#{img}"
    end

    #copy all files into zip
    input_files = Dir.entries(task_dir).select { | f | (f =~ /^\d{3}.(cover|document|code|image)/) == 0 }

    zip_dir = File.dirname(zip_file)
    if not Dir.exists? zip_dir
      FileUtils.mkdir_p zip_dir
    end

    Zip::File.open(zip_file, Zip::File::CREATE) do | zip |
      zip.mkdir "#{id}"
      input_files.each do |in_file|
        zip.add "#{id}/#{in_file}", "#{task_dir}#{in_file}"
      end
    end

    FileUtils.rm_rf(task_dir)
  end

  def clear_in_process
    in_process_dir = student_work_dir(:in_process, false)
    if Dir.exists? in_process_dir
      if FileUtils.pwd == in_process_dir
        Dir.chdir(FileUtils.student_work_dir())
      end
      FileUtils.rm_rf in_process_dir
    end
  end

  #
  # Move folder over from done -> new
  # Allowing task pdf to be recreated next time pdfs are generated
  #
  def move_done_to_new
    done = student_work_dir(:done, false)

    if Dir.exists? done
      new_task_dir = student_work_dir(:new, false)
      FileUtils.mkdir_p(new_task_dir)
      FileHelper.move_files(done, new_task_dir)
      true
    elsif FileHelper.move_compressed_task_to_new(self)
      true
    else
      false
    end
  end

  #
  # Move folder over from new or done -> in_process returns true on success
  #
  def move_files_to_in_process
    # find and clear out old dir
    in_process_dir = student_work_dir(:in_process, false)

    return false if in_process_dir.nil?

    if Dir.exists? in_process_dir
      pwd = FileUtils.pwd
      Dir.chdir(in_process_dir)
      # move all files to the enq dir
      FileUtils.rm Dir.glob("*")
      Dir.chdir(pwd)
    end

    from_dir = student_work_dir(:new, false)
    if Dir.exists?(from_dir)
      #save new files in done folder
      compress_new_to_done
    end

    zip_file = zip_file_path_for_done_task()
    if zip_file && File.exists?(zip_file)
      extract_file_from_done FileHelper.student_work_dir(:new), "*", lambda { | task, to_path, name |  "#{to_path}#{name}" }
      return false if not Dir.exists?(from_dir)
    else
      return false
    end

    # Move files from new to in process
    FileHelper.move_files(from_dir, in_process_dir)
    return true
  end

  def __output_filename__(in_dir, idx, type)
    pwd = FileUtils.pwd
    Dir.chdir(in_dir)

    result = Dir.glob("#{idx.to_s.rjust(3, '0')}.#{type}.*").first
    if (not result.nil?) && File.exists?(result)
      FileUtils.mv result, "#{idx.to_s.rjust(3, '0')}-#{type}#{File.extname(result)}"
    end

    result = Dir.glob("#{idx.to_s.rjust(3, '0')}-#{type}.*").first
    Dir.chdir(pwd)
    return File.join(in_dir, result) unless result.nil?
    nil
  end

  def in_process_files_for_task
    magic = FileMagic.new(FileMagic::MAGIC_MIME)
    in_process_dir = student_work_dir(:in_process, false)
    return [] if not Dir.exists? in_process_dir

    result = []

    idx = 0
    upload_requirements.each do |file_req|
      output_filename = __output_filename__(in_process_dir, idx, file_req['type'])

      if output_filename.nil?
        idx += 1 # skip headers if present
        output_filename = __output_filename__(in_process_dir, idx, file_req['type'])
      end

      if output_filename.nil?
        logger.error "Error processing task #{id} - missing file #{file_req}"
        puts "Error processing task #{id} - missing file #{file_req}"
      else
        result << { path: output_filename, type: file_req['type'] }

        if file_req['type'] == 'code' && magic.file(output_filename).include?('utf-16')
          #convert utf-16 to utf-8
          #TODO: avoid system call... if we can work out how to get ruby to save as UTF8
          `iconv -f UTF-16 -t UTF-8 "#{output_filename}" > new`
          FileUtils.mv('new', output_filename)
        end

        idx += 1 # next file index
      end
    end

    result
  end

  class TaskAppController < ApplicationController
    attr_accessor :task
    attr_accessor :files
    attr_accessor :base_path
    attr_accessor :image_path

    def init(task)
      @task = task
      @files = task.in_process_files_for_task
      @base_path = task.student_work_dir(:in_process, false)
      @image_path = Rails.root.join("public", "assets", "images")
    end

    def make_pdf()
      render_to_string(:template => "/task/task_pdf.pdf.erb", :layout => true)
    end
  end

  def pygments_lang(extn)
    extn = extn.downcase
    case
      when ['pas', 'pp'].include?(extn) then 'pas'
      when ['cs'].include?(extn) then 'csharp'
      when ['c', 'h', 'idc'].include?(extn) then 'c'
      when ['cpp', 'hpp', 'c++', 'h++', 'cc', 'cxx', 'cp'].include?(extn) then 'cpp'
      when ['java'].include?(extn) then 'java'
      when ['js'].include?(extn) then 'js'
      when ['html'].include?(extn) then 'html'
      when ['css'].include?(extn) then 'css'
      when ['rb'].include?(extn) then 'ruby'
      when ['coffee'].include?(extn) then 'coffeescript'
      when ['yaml', 'yml'].include?(extn) then 'yaml'
      when ['xml'].include?(extn) then 'xml'
      when ['scss'].include?(extn) then 'scss'
      when ['json'].include?(extn) then 'json'
      when ['ts'].include?(extn) then 'ts'
      else 'c'
    end
  end

  def final_pdf_path()
    if group_task?
      return nil if group_submission.nil? || group_submission.task_definition.nil?

      File.join(
        FileHelper.student_group_work_dir(:pdf, group_submission, task=nil, create=true),
        FileHelper.sanitized_filename(FileHelper.sanitized_path("#{group_submission.task_definition.abbreviation}-#{group_submission.id}") + ".pdf"))
    else
      File.join(student_work_dir(:pdf), FileHelper.sanitized_filename( FileHelper.sanitized_path("#{task_definition.abbreviation}-#{id}") + ".pdf"))
    end
  end

  def convert_submission_to_pdf
    return false unless move_files_to_in_process()

    begin
      tac = TaskAppController.new
      tac.init(self)

      pdf_text = tac.make_pdf

      if group_task?
        group_submission.tasks.each do |t|
          t.portfolio_evidence = final_pdf_path
          t.save
        end
        reload
      else
        self.portfolio_evidence = final_pdf_path
      end

      File.open(self.portfolio_evidence, 'w') do |fout|
        fout.puts pdf_text
      end

      FileHelper.compress_pdf(self.portfolio_evidence)

      self.save

      clear_in_process()
      return true
    rescue => e
      logger.error "Failed to convert submission to PDF for task #{id}. Error: #{e.message}"
      puts "Failed to convert submission to PDF for task #{id}. Error: #{e.message}"

      add_comment project.main_tutor, "**Automated Comment**: Failed to process submitted files. Check code files submitted for invalid characters, that documents are valid pdfs, and that images are valid."
      trigger_transition 'fix', project.main_tutor

      return false
    end
  end

  #
  # The student has uploaded new work...
  #
  def create_submission_and_trigger_state_change (user, propagate = true, contributions = nil, trigger = 'ready_to_mark')
    if group_task? && propagate
      if contributions.nil? # even distribution
        contribs = group.projects.map { |proj| { project: proj, pct: 100 / group.projects.count }  }
      else
        contribs = contributions.map { |data| { project: Project.find(data[:project_id]), pct: data[:pct].to_i }  }
      end
      group_submission = group.create_submission self, "#{user.name} has submitted work", contribs
      group_submission.tasks.each { |t| t.create_submission_and_trigger_state_change(user, propagate=false) }
      reload
    else
      self.file_uploaded_at = DateTime.now

      # This task is now ready to submit
      if not (discuss_or_demonstrate? || complete? || do_not_resubmit? || fail?)
        self.trigger_transition trigger, user, false, false # dont propagate -- already done

        plagiarism_match_links.each do | link |
          link.destroy
        end
        reverse_plagiarism_match_links do | link |
          link.destroy
        end
      end
      save
    end
  end

  #
  # Moves submission into place
  #
  def accept_submission(current_user, files, student, ui, contributions, trigger)
    #
    # Ensure that each file in files has the following attributes:
    # id, name, filename, type, tempfile
    #
    files.each do | file |
      ui.error!({"error" => "Missing file data for '#{file.name}'"}, 403) if file.id.nil? || file.name.nil? || file.filename.nil? || file.type.nil? || file.tempfile.nil?
    end

    # Ensure group if group task
    if group_task? && group.nil?
      ui.error!({"error" => "You must be in a group to submit this task."}, 403)
    end

    # file.key            = "file0"
    # file.name           = front end name for file
    # file.tempfile.path  = actual file dir
    # file.filename       = their name for the file

    #
    # Confirm subtype categories using filemagic
    #
    files.each_with_index do | file, index |
      logger.debug "Accepting submission (file #{index + 1} of #{files.length}) - checking file type for #{file.tempfile.path}"
      if not FileHelper.accept_file(file, file.name, file.type)
        ui.error!({"error" => "'#{file.name}' is not a valid #{file.type} file"}, 403)
      end

      if File.size(file.tempfile.path) > 5000000
        ui.error!({"error" => "'#{file.name}' exceeds the 5MB file limit. Try compressing or reformat and submit again."}, 403)
      end
    end

    create_submission_and_trigger_state_change(current_user, propagate = true, contributions = contributions, trigger = trigger)

    #
    # Create student submission folder (<tmpdir>/doubtfire/new/<id>)
    #
    tmp_dir = File.join( Dir.tmpdir, 'doubtfire', 'new', "#{id}" )
    logger.debug "Creating temporary directory for new dubmission at #{tmp_dir}"

    # ensure the dir exists
    FileUtils.mkdir_p(tmp_dir)

    #
    # Set portfolio_evidence to nil while it gets processed
    #
    portfolio_evidence = nil

    files.each_with_index.map do | file, idx |
      output_filename = File.join(tmp_dir, "#{idx.to_s.rjust(3, '0')}-#{file.type}#{File.extname(file.filename).downcase}")
      FileUtils.cp file.tempfile.path, output_filename
    end

    #
    # Now copy over the temp directory over to the enqueued directory
    #
    enqueued_dir = student_work_dir(:new, self)[0..-2]

    logger.debug "Moving submission evidence from #{tmp_dir} to #{enqueued_dir}"

    pwd = FileUtils.pwd
    # move to tmp dir
    Dir.chdir(tmp_dir)
    # move all files to the enq dir
    FileUtils.mv Dir.glob("*"), enqueued_dir
    # FileUtils.rm Dir.glob("*")
    # remove the directory
    Dir.chdir(pwd)
    Dir.rmdir(tmp_dir)

    logger.debug "Submission accepted! Status for task #{id} is now #{trigger}"
  end
end
