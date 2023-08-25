require 'date'

class Task < ApplicationRecord
  include ApplicationHelper
  include LogHelper
  include GradeHelper

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
      :delete_own_comment,
      :start_discussion,
      :get_discussion,
      :make_discussion_reply,
      # :request_extension -- depends on settings in unit. See specific_permission_hash method
    ]
    # What can tutors do with tasks?
    tutor_role_permissions = [
      :get,
      :put,
      :get_submission,
      :make_submission,
      :delete_other_comment,
      :delete_own_comment,
      :view_plagiarism,
      :delete_plagiarism,
      :create_discussion,
      :delete_discussion,
      :get_discussion,
      :assess_extension,
      :request_extension
    ]
    # What can convenors do with tasks?
    convenor_role_permissions = [
      :get,
      :get_submission,
      :make_submission,
      :delete_other_comment,
      :delete_own_comment,
      :view_plagiarism,
      :delete_plagiarism,
      :get_discussion,
      :assess_extension,
      :request_extension
    ]
    # What can nil users do with tasks?
    nil_role_permissions = []

    # Return permissions hash
    {
      student: student_role_permissions,
      tutor: tutor_role_permissions,
      convenor: convenor_role_permissions,
      nil: nil_role_permissions
    }
  end

  def role_for(user)
    project_role = project.user_role(user)
    return project_role unless project_role.nil?

    logger.debug "Getting role for user #{user.id unless user.nil?}: #{task_definition.abbreviation} #{task_definition.group_set}"
    # check for group member
    if group_task?
      logger.debug 'Checking group'
      if group && group.has_user(user)
        return :group_member
      else
        return nil
      end
    end
  end

  # Used to adjust the request extension permission in units that do not
  # allow students to request extensions
  def specific_permission_hash(role, perm_hash, _other)
    result = perm_hash[role] unless perm_hash.nil?
    if result && role == :student && unit.allow_student_extension_requests
      result << :request_extension
    end
    result
  end

  # Delete action - before dependent association
  before_destroy :delete_associated_files

  # Model associations
  belongs_to :task_definition, optional: false       # Foreign key
  belongs_to :project, optional: false               # Foreign key
  belongs_to :task_status, optional: false           # Foreign key
  belongs_to :group_submission, optional: true

  has_one :unit, through: :project

  has_many :comments, class_name: 'TaskComment', dependent: :destroy, inverse_of: :task
  has_many :task_similarities, class_name: 'TaskSimilarity', dependent: :destroy, inverse_of: :task
  has_many :reverse_task_similarities, class_name: 'MossTaskSimilarity', dependent: :destroy, inverse_of: :other_task, foreign_key: 'other_task_id'
  has_many :learning_outcome_task_links, dependent: :destroy # links to learning outcomes
  has_many :learning_outcomes, through: :learning_outcome_task_links
  has_many :task_engagements, dependent: :destroy
  has_many :task_submissions, dependent: :destroy
  has_many :overseer_assessments, dependent: :destroy
  has_many :tii_submissions, dependent: :destroy

  delegate :unit, to: :project
  delegate :student, to: :project
  delegate :upload_requirements, to: :task_definition
  delegate :name, to: :task_definition
  delegate :target_date, to: :task_definition
  delegate :update_task_stats, to: :project

  after_update :update_task_stats, if: :saved_change_to_task_status_id? # TODO: consider moving to async task

  validates :task_definition_id, uniqueness: { scope: :project,
                                               message: 'must be unique within the project' }

  validate :must_have_quality_pts, if: :for_definition_with_quality?

  validate :extensions_must_end_with_due_date, if: :has_requested_extension?

  include TaskTiiModule

  def for_definition_with_quality?
    task_definition.has_stars?
  end

  def has_requested_extension?
    extensions > 0 && will_save_change_to_extensions? && extensions > extensions_in_database
  end

  def must_have_quality_pts
    if quality_pts.nil? || quality_pts < -1 || quality_pts > task_definition.max_quality_pts
      errors.add(:quality_pts, "must be between 0 and #{task_definition.max_quality_pts}")
    end
  end

  # Ensure that extensions do not exceed the defined due date
  def extensions_must_end_with_due_date
    # First check the raw extension date - but allow it to be up to a week later in case due date and target date are on different days
    if raw_extension_date.to_date - 7.days >= task_definition.due_date.to_date
      errors.add(:extensions, "have exceeded deadline for task. Work must be submitted within current timeframe. Work submitted after current due date will be assessed in the portfolio")
    end
  end

  def description
    "#{task_definition.abbreviation} for #{project.student.username}"
  end

  def all_comments
    if group_submission.nil?
      comments
    else
      TaskComment.joins(:task).where('tasks.group_submission_id = :id', id: group_submission.id)
    end
  end

  def mark_comments_as_read(user, comments)
    comments.each do |comment|
      comment.mark_as_read(user, unit)
    end
  end

  def mark_comments_as_unread(user, comments)
    comments.each do |comment|
      comment.mark_as_unread(user)
    end
  end

  def comments_for_user(user)
    TaskComment
      .joins('JOIN users AS authors ON authors.id = task_comments.user_id')
      .joins('JOIN users AS recipients ON recipients.id = task_comments.recipient_id')
      .joins("LEFT JOIN comments_read_receipts u_crr ON u_crr.task_comment_id = task_comments.id AND u_crr.user_id = #{user.id}")
      .joins("LEFT JOIN comments_read_receipts r_crr ON r_crr.task_comment_id = task_comments.id AND r_crr.user_id = recipients.id")
      .where('task_comments.task_id = :task_id', task_id: self.id)
      .order('created_at ASC')
      .select(
        'task_comments.id AS id',
        'task_comments.comment AS comment',
        'task_comments.content_type AS content_type',
        "case when u_crr.created_at IS NULL then 1 else 0 end AS is_new",
        'r_crr.created_at AS recipient_read_time',
        'task_comments.created_at AS created_at',
        'authors.id AS author_id',
        'authors.first_name AS author_first_name',
        'authors.last_name AS author_last_name',
        'authors.email AS author_email',
        'recipients.id AS recipient_id',
        'recipients.first_name AS recipient_first_name',
        'recipients.last_name AS recipient_last_name',
        'recipients.email AS recipient_email',
        'task_comments.reply_to_id AS reply_to_id'
      )
  end

  def current_task_similarities
    task_similarities.where(dismissed: false)
  end

  def self.for_unit(unit_id)
    Task.joins(:project).where('projects.unit_id = :unit_id', unit_id: unit_id)
  end

  def self.for_user(user)
    Task.joins(:project).where('projects.user_id = ?', user.id)
  end

  def processing_pdf?
    if group_task? && group_submission
      File.exist? File.join(FileHelper.student_work_dir(:new), group_submission.submitter_task.id.to_s)
    else
      File.exist? File.join(FileHelper.student_work_dir(:new), id.to_s)
    end
  end

  # Get the raw extension date - with extensions representing weeks
  def raw_extension_date
    target_date + extensions.weeks
  end

  # Get the adjusted extension date, which ensures it is never past the due date
  def extension_date
    result = raw_extension_date
    return task_definition.due_date if result > task_definition.due_date

    return result
  end

  # The student can apply for an extension if the current extension date is
  # before the task's due date
  def can_apply_for_extension?
    raw_extension_date.to_date < task_definition.due_date.to_date
  end

  def tutor
    project.tutor_for(task_definition)
  end

  # Applying for an extension will create an extension comment
  def apply_for_extension(user, text, weeks)
    extension = ExtensionComment.create
    extension.task = self
    extension.extension_weeks = weeks
    extension.user = user
    extension.content_type = :extension
    extension.comment = text
    if weeks <= weeks_can_extend
      extension.recipient = tutor
    else
      extension.recipient = unit.main_convenor_user
    end
    extension.save!

    # Check and apply either auto extensions, or those requested by staff
    if (unit.auto_apply_extension_before_deadline && weeks <= weeks_can_extend) || role_for(user) == :tutor
      if role_for(user) == :tutor
        extension.assess_extension user, true, true
      else
        extension.assess_extension unit.main_convenor_user, true, true
      end
    end

    extension
  end

  def weeks_can_extend
    deadline = task_definition.due_date.to_date
    current_due = raw_extension_date.to_date

    diff = deadline - current_due
    (diff.to_f / 7).ceil
  end

  # Add an extension to the task
  def grant_extension(by_user, weeks)
    weeks_to_extend = [weeks, weeks_can_extend].min
    return false unless weeks_to_extend > 0

    if update(extensions: self.extensions + weeks_to_extend)
      # Was the task previously assessed as time exceeded? ... with the extension should this change?
      if self.task_status == TaskStatus.time_exceeded && submitted_before_due?
        update(task_status: TaskStatus.ready_for_feedback)
        add_status_comment(by_user, self.task_status)
      end

      return true
    else
      return false
    end
  end

  def due_date
    return target_date if extensions == 0

    return extension_date
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
    complete? || discuss_or_demonstrate? || feedback_exceeded? || fail?
  end

  def ready_for_feedback?
    status == :ready_for_feedback
  end

  def ready_or_complete?
    [:complete, :discuss, :demonstrate, :ready_for_feedback].include? status
  end

  def submitted_status?
    ![:working_on_it, :not_started, :fix_and_resubmit, :redo, :need_help].include? status
  end

  def fix_and_resubmit?
    status == :fix_and_resubmit
  end

  def feedback_exceeded?
    status == :feedback_exceeded
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

  def reviewable?
    has_pdf && (ready_for_feedback? || need_help?)
  end

  def status
    task_status.status_key
  end

  def has_pdf
    !portfolio_evidence_path.nil? && File.exist?(portfolio_evidence_path) && !processing_pdf?
  end

  def log_details
    "#{id} - #{project.student.username}, #{project.unit.code}, #{task_definition.abbreviation}"
  end

  def group_task?
    !group_submission.nil? || !task_definition.group_set.nil?
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

    group.create_submission self, '', group.projects.map { |proj| { project: proj, pct: 100 / group.projects.count } }
  end

  def trigger_transition(trigger: '', by_user: nil, bulk: false, group_transition: false, quality: 1)
    #
    # Ensure that assessor is allowed to update the task in the indicated way
    #
    role = role_for(by_user)

    return nil if role.nil?

    #
    # Ensure that only staff can change from staff assigned status if
    # this is a restricted task
    #
    return nil if [:student, :group_member].include?(role) &&
                  task_definition.restrict_status_updates &&
                  task_status.in?(TaskStatus.staff_assigned_statuses)

    # Protect closed states from student changes
    return nil if [:student, :group_member].include?(role) && task_submission_closed?

    #
    # State transitions based upon the trigger
    #

    status = TaskStatus.status_for_name(trigger)

    case status
    when nil
      return nil
    when TaskStatus.ready_for_feedback
      submit by_user
    when TaskStatus.not_started, TaskStatus.need_help, TaskStatus.working_on_it
      add_status_comment(by_user, status)
      engage status
    else
      # Only tutors can perform these actions
      if role == :tutor
        if task_definition.max_quality_pts > 0
          case status
          when TaskStatus.complete, TaskStatus.discuss, TaskStatus.demonstrate
            update(quality_pts: quality)
          end
        end
        assess status, by_user

        # Add a status comment for new assessments - only recorded on submitter's task in groups
        add_status_comment(by_user, status)
      else
        # Attempt to move to tutor state by non-tutor
        return nil
      end
    end

    # if this is a status change of a group task -- and not already doing group update
    if !group_transition && group_task?
      logger.debug "Group task transition for #{group_submission} set to status #{trigger} (id=#{id})"
      unless [TaskStatus.working_on_it, TaskStatus.need_help].include? task_status
        ensured_group_submission.propagate_transition self, trigger, by_user, quality
      end
    end

    true
  end

  def grade_desc
    grade_for(grade)
  end

  #
  # Tries to grade the task if it is a graded task
  #
  def grade_task(new_grade, ui = nil, grading_group = false)
    raise_error = lambda do |message|
      ui.error!({ 'error' => message }, 403) unless ui.nil?
      raise message
    end

    grade_map = {
      'f' => -1,
      'p' => 0,
      'c' => 1,
      'd' => 2,
      'hd' => 3
    }
    if task_definition.is_graded
      if new_grade.nil?
        raise_error.call("No grade was supplied for a graded task (task id #{id})")
      else
        # validate (and convert if need be) new_grade
        unless new_grade.is_a?(String) || new_grade.is_a?(Integer)
          raise_error.call("New grade supplied to task is not a string or integer (task id #{id})")
        end
        if new_grade.is_a?(String)
          if grade_map.keys.include?(new_grade.downcase)
            # convert string representation to integer representation
            new_grade = grade_map[new_grade]
          else
            raise_error.call("New grade supplied to task is not a valid string - expects one of {f|p|c|d|hd} (task id #{id})")
          end
        end
        unless new_grade.is_a?(Integer) && grade_map.values.include?(new_grade.to_i)
          raise_error.call("New grade supplied to task is not a valid integer - expects one of {-1|0|1|2|3} (task id #{id})")
        end
        # propagate new grade to all OTHER group members
        if group_task? && !grading_group
          logger.debug "Grading a group submission to grade #{new_grade}"
          ensured_group_submission.propagate_grade self, new_grade, ui
        end

        # now update this task... (may be group task or individual...)
        logger.debug "Grading task #{id} in a group submission to grade #{new_grade}"
        update(grade: new_grade)
      end
    elsif grade?
      raise_error.call("Grade was supplied for a non-graded task (task id #{id})")
    end
  end

  def assess(task_status, assessor, assess_date = Time.zone.now)
    # Set the task's status to the assessment outcome status
    # and flag it as no longer awaiting signoff
    self.task_status = task_status

    # Ensure it has a submission date
    self.submission_date = assess_date if submission_date.nil?

    # Set the assessment date and update the times assessed
    if assessment_date.nil? || assessment_date < submission_date
      # only a new assessment if it was submitted after last assessment
      self.times_assessed += 1
    end
    self.assessment_date = assess_date

    # Set the completion date of the task if it's been completed
    if ready_or_complete?
      self.completion_date = assess_date if completion_date.nil?
    else
      self.completion_date = nil

      # Grant an extension on fix if due date is within 1 week
      case task_status
      when TaskStatus.fix_and_resubmit, TaskStatus.discuss, TaskStatus.demonstrate
        if to_same_day_anywhere_on_earth(due_date) < Time.zone.now + 7.days && can_apply_for_extension? && unit.extension_weeks_on_resubmit_request > 0
          grant_extension(assessor, unit.extension_weeks_on_resubmit_request)
        end
      end
    end

    # Save the task
    if save!
      TaskEngagement.create!(task: self, engagement_time: Time.zone.now, engagement: task_status.name)

      # Grab the submission for the task if the user made one
      submission = TaskSubmission.where(task_id: id).order(:submission_time).reverse_order.first
      # Prepare the attributes of the submission
      submission_attributes = { task: self, assessment_time: assess_date, assessor: assessor, outcome: task_status.name }

      # Create or update the submission depending on whether one was made
      if submission.nil?
        submission_attributes[:submission_time] = assess_date
        submission = TaskSubmission.create! submission_attributes
      else
        # we have an existing submission
        if submission.assessment_time.nil?
          # and it hasn't been assessed yet...
          submission.update submission_attributes
          submission.save
        else
          # it was assessed... so lets create a new assessment
          submission_attributes[:submission_time] = submission.submission_time
          submission = TaskSubmission.create! submission_attributes
        end
      end
    end
  end

  def engage(engagement_status)
    self.task_status = engagement_status

    if save!
      TaskEngagement.create!(task: self, engagement_time: Time.zone.now, engagement: task_status.name)
    end
  end

  def submitted_before_due?
    return true unless due_date.present?

    to_same_day_anywhere_on_earth(due_date) >= self.submission_date
  end

  #
  # A task has been submitted - update the status and record the submission
  # Default submission time to current time.
  #
  def submit(by_user, submit_date = Time.zone.now)
    self.submission_date = submit_date

    add_status_comment(by_user, TaskStatus.ready_for_feedback)

    # If it is submitted before the due date...
    if submitted_before_due?
      self.task_status = TaskStatus.ready_for_feedback
    else
      assess TaskStatus.time_exceeded, by_user
      add_status_comment(project.tutor_for(task_definition), self.task_status)
      grade_task(-1) if task_definition.is_graded? && self.grade.nil?
    end

    if save!
      TaskEngagement.create!(task: self, engagement_time: Time.zone.now, engagement: task_status.name)
      submission = TaskSubmission.where(task_id: id).order(:submission_time).reverse_order.first

      if submission.nil?
        TaskSubmission.create!(task: self, submission_time: submit_date)
      else
        if (!submission.submission_time.nil?) && submit_date < submission.submission_time + 1.hour && submission.assessor.nil?
          # update old submission if within time window
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
      feedback_exceeded? ||
      fail? ||
      complete?
  end

  def weight
    task_definition.weighting.to_f
  end

  def add_text_comment(user, text, reply_to_id = nil)
    text.strip!
    return nil if user.nil? || text.nil? || text.empty?

    lc = comments.last

    # don't add if duplicate comment
    return if lc && lc.user == user && lc.comment == text

    ensured_group_submission if group_task? && group

    comment = TaskComment.create
    comment.task = self
    comment.user = user
    comment.comment = text
    comment.content_type = :text
    comment.recipient = user == project.student ? project.tutor_for(task_definition) : project.student
    comment.reply_to_id = reply_to_id
    comment.save!

    comment
  end

  def individual_task_or_submitter_of_group_task?
    return true if !group_task? # its individual
    return true unless group.present? # no group yet... so individual

    ensured_group_submission.submitted_by? self.project # return true if submitted by this project
  end

  def add_status_comment(current_user, status)
    return nil unless individual_task_or_submitter_of_group_task? # only record status comments on submitter task

    comment = TaskStatusComment.create
    comment.task = self
    comment.user = current_user
    comment.comment = status.name
    comment.task_status = status
    comment.recipient = current_user == project.student ? project.tutor_for(task_definition) : project.student
    comment.save!

    comment
  end

  def add_discussion_comment(user, prompts)
    # don't allow if group task.
    discussion = DiscussionComment.create
    discussion.task = self
    discussion.user = user
    discussion.content_type = :discussion
    discussion.recipient = project.student
    discussion.number_of_prompts = prompts.count
    discussion.save!

    prompts.each_with_index do |prompt, index|
      raise "Unknown comment attachment type" unless FileHelper.accept_file(prompt, "comment attachment discussion audio", "audio")
      raise "Error attaching uploaded file." unless discussion.add_prompt(prompt, index)
    end

    discussion.mark_as_read(user, unit)

    logger.info(discussion)
    return discussion
  end

  # TODO: Refactor to attachment comment (with inheritance on model)
  def add_comment_with_attachment(user, tempfile, reply_to_id = nil)
    ensured_group_submission if group_task? && group

    comment = TaskComment.create
    comment.task = self
    comment.user = user
    comment.reply_to_id = reply_to_id
    if FileHelper.accept_file(tempfile, "comment attachment audio test", "audio")
      comment.content_type = :audio
    elsif FileHelper.accept_file(tempfile, "comment attachment image test", "image")
      comment.content_type = :image
    elsif FileHelper.accept_file(tempfile, "comment attachment pdf", "document")
      comment.content_type = :pdf
    else
      raise "Unknown comment attachment type"
    end

    comment.recipient = user == project.student ? project.tutor_for(task_definition) : project.student
    raise "Error attaching uploaded file." unless comment.add_attachment(tempfile)

    comment.save!
    comment
  end

  def last_comment
    all_comments.last
  end

  def last_comment_by(user)
    result = all_comments.where(user: user).last

    return '' if result.nil?

    result.comment
  end

  def has_comment_by(user)
    !last_comment_by(user).empty?
  end

  def is_last_comment_by?(user)
    last_comment = all_comments.last
    return false if last_comment.nil?

    last_comment.user == user
  end

  def last_comment_not_by(user)
    result = all_comments.where('user_id != :id', id: user.id).last

    return '' if result.nil?

    result.comment
  end

  def student_work_dir(type, create = true)
    if group_task?
      # New submissions need to use the path of this task
      if type == :new
        FileHelper.student_group_work_dir(type, group_submission, self, create)
      else
        FileHelper.student_group_work_dir(type, group_submission, group_submission.submitter_task, create)
      end
    else
      FileHelper.student_work_dir(type, self, create)
    end
  end

  def zip_file_path_for_done_task
    if group_task?
      if group_submission.nil?
        logger.warn("Missing group submission from task identified for task #{id}!")
        "#{Doubtfire::Application.config.student_work_dir}/#{FileHelper.sanitized_path("#{project.unit.code}-#{project.unit.id}", project.student.username.to_s, 'done', id.to_s)[0..-1]}.zip"
      else
        "#{FileHelper.student_group_work_dir(:done, group_submission)[0..-2]}.zip"
      end
    else
      "#{student_work_dir(:done, false)[0..-2]}.zip"
    end
  end

  def extract_file_from_done(to_path, pattern, name_fn)
    zip_file = zip_file_path_for_done_task
    return false if zip_file.nil? || (!File.exist? zip_file)

    Zip::File.open(zip_file) do |zip|
      # Extract folders
      zip.each do |entry|
        # Extract to file/directory/symlink
        logger.debug "Extracting file from done: #{entry.name}"
        if entry.name_is_directory?
          entry.extract(name_fn.call(self, to_path, entry.name)) { true }
        end
      end
      zip.glob("**/#{pattern}").each do |entry|
        entry.extract(name_fn.call(self, to_path, entry.name)) { true }
      end
    end
  end

  def has_new_files?
    File.directory? student_work_dir(:new, false)
  end

  def has_done_file?
    File.exist? zip_file_path_for_done_task
  end

  #
  # Compress the done files for a student - includes cover page and work uploaded
  #
  def compress_new_to_done(task_dir: student_work_dir(:new, false), zip_file_path: nil, rm_task_dir: true, rename_files: false)
    begin
      # Ensure that this task is the submitter task for a  group_task... otherwise
      # remove this submission
      raise "Multiple team member submissions received at the same time. Please ensure that only one member submits the task." if group_task? && self != group_submission.submitter_task

      zip_file = zip_file_path || zip_file_path_for_done_task
      return false if zip_file.nil? || (!Dir.exist? task_dir)

      FileUtils.rm_f(zip_file)

      # compress image files
      image_files = Dir.entries(task_dir).select { |f| (f =~ /^\d{3}.(image)/) == 0 }
      image_files.each do |img|
        # Ensure all images in submissions are not jpg
        dest_file = "#{task_dir}#{File.basename(img, ".*")}.jpg"
        raise 'Failed to compress an image. Ensure all images are valid.' unless FileHelper.compress_image_to_dest("#{task_dir}#{img}", dest_file, true)

        # Cleanup unless the output was the same as the input
        FileUtils.rm("#{task_dir}#{img}") unless dest_file == "#{task_dir}#{img}"
      end

      # copy all files into zip
      input_files = Dir.entries(task_dir).select { |f| (f =~ /^\d{3}.(cover|document|code|image)/) == 0 }

      zip_dir = File.dirname(zip_file)
      FileUtils.mkdir_p zip_dir

      Zip::File.open(zip_file, Zip::File::CREATE) do |zip|
        zip.mkdir id.to_s
        input_files.each do |in_file|
          final_name = in_file

          if rename_files
            index = in_file.to_i
            file = upload_requirements[index]
            final_name = file['name']
          end
          zip.add "#{id}/#{final_name}", "#{task_dir}#{in_file}"
        end
      end
    ensure
      FileUtils.rm_rf(task_dir) if rm_task_dir
    end

    true
  end

  def copy_done_to(path)
    FileUtils.cp zip_file_path_for_done_task, path
  end

  def clear_in_process
    in_process_dir = student_work_dir(:in_process, false)
    if Dir.exist? in_process_dir
      Dir.chdir(FileUtils.student_work_dir) if FileUtils.pwd == in_process_dir
      FileUtils.rm_rf in_process_dir
    end
  end

  #
  # Move folder over from done -> new
  # Allowing task pdf to be recreated next time pdfs are generated
  #
  def move_done_to_new
    done = student_work_dir(:done, false)

    if Dir.exist? done
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
  def move_files_to_in_process(source_folder = FileHelper.student_work_dir(:new))
    # find and clear out old dir
    in_process_dir = student_work_dir(:in_process, false)

    return false if in_process_dir.nil?

    if Dir.exist? in_process_dir
      pwd = FileUtils.pwd
      Dir.chdir(in_process_dir)
      # move all files to the enq dir
      FileUtils.rm Dir.glob('*')
      Dir.chdir(pwd)
    end

    # Zip new submission and store in done files (will remove from_dir) - ensure trailing /
    from_dir = File.join(source_folder, id.to_s) + "/"
    if Dir.exist?(from_dir)
      # save new files in done folder
      return false unless compress_new_to_done(task_dir: from_dir)
    end

    # Get the zip file path...
    zip_file = zip_file_path_for_done_task
    if zip_file && File.exist?(zip_file)
      # extract to root in process dir - as it contains the folder in the zip file
      extract_file_from_done FileHelper.student_work_dir(:in_process), '*', lambda { |_task, to_path, name|
        "#{to_path}#{name}"
      }
      return Dir.exist?(in_process_dir)
    else
      return false
    end
  end

  def __output_filename__(in_dir, idx, type)
    pwd = FileUtils.pwd
    Dir.chdir(in_dir)
    begin
      # Rename files with 000.type.* to 000-type-*
      result = Dir.glob("#{idx.to_s.rjust(3, '0')}.#{type}.*").first

      if !result.nil? && File.exist?(result)
        FileUtils.mv result, "#{idx.to_s.rjust(3, '0')}-#{type}#{File.extname(result)}"
      end
      result = Dir.glob("#{idx.to_s.rjust(3, '0')}-#{type}.*").first
    ensure
      Dir.chdir(pwd)
    end

    return File.join(in_dir, result) unless result.nil?

    nil
  end

  def in_process_files_for_task(is_retry)
    magic = FileMagic.new(FileMagic::MAGIC_MIME)
    in_process_dir = student_work_dir(:in_process, false)
    return [] unless Dir.exist? in_process_dir

    result = []

    idx = 0
    upload_requirements.each do |file_req|
      output_filename = __output_filename__(in_process_dir, idx, file_req['type'])

      if output_filename.nil?
        idx += 1 # skip headers if present
        output_filename = __output_filename__(in_process_dir, idx, file_req['type'])
      end

      if output_filename.nil?
        logger.error "Error processing task #{log_details} - missing file #{file_req}"
        raise "File `#{file_req['name']}` missing from submission."
      else
        result << { path: output_filename, type: file_req['type'] }

        if file_req['type'] == 'code'
          FileHelper.ensure_utf8_code(output_filename, is_retry)
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
    attr_accessor :include_pax

    def init(task, is_retry)
      @task = task
      @files = task.in_process_files_for_task(is_retry)
      @base_path = task.student_work_dir(:in_process, false)
      @image_path = Rails.root.join('public', 'assets', 'images')
      @institution_name = Doubtfire::Application.config.institution[:name]
      @doubtfire_product_name = Doubtfire::Application.config.institution[:product_name]
      @include_pax = !is_retry
    end

    def make_pdf
      logger.debug "Running QPDF on all documents before rendering to repair any potential broken files."
      @files.each do |f|
        if f[:type] == "document"
          FileHelper.qpdf(f[:path])
        end
      end
      render_to_string(template: '/task/task_pdf', layout: true)
    end
  end

  def self.pygments_lang(extn)
    extn = extn.downcase
    if %w(pas pp).include?(extn) then 'pas'
    elsif ['cs'].include?(extn) then 'csharp'
    elsif %w(c h idc).include?(extn) then 'c'
    elsif ['cpp', 'hpp', 'c++', 'h++', 'cc', 'cxx', 'cp'].include?(extn) then 'cpp'
    elsif ['java'].include?(extn) then 'java'
    elsif %w(js json ts).include?(extn) then 'js'
    elsif ['html', 'rhtml'].include?(extn) then 'html'
    elsif %w(css scss).include?(extn) then 'css'
    elsif ['rb'].include?(extn) then 'ruby'
    elsif ['coffee'].include?(extn) then 'coffeescript'
    elsif %w(yaml yml).include?(extn) then 'yaml'
    elsif ['xml'].include?(extn) then 'xml'
    elsif ['sql'].include?(extn) then 'sql'
    elsif ['vb'].include?(extn) then 'vbnet'
    elsif ['txt', 'md', 'rmd', 'rpres', 'hdl', 'asm', 'jack', 'hack', 'tst', 'cmp', 'vm', 'sh', 'bat', 'dat', 'csv'].include?(extn) then 'text'
    elsif ['tex', 'rnw'].include?(extn) then 'tex'
    elsif ['py'].include?(extn) then 'python'
    elsif ['r'].include?(extn) then 'r'
    else extn
    end
  end

  def portfolio_evidence_path
    # Add the student work dir to the start of the portfolio evidence
    File.join(FileHelper.student_work_dir, self.portfolio_evidence) if self.portfolio_evidence.present?
  end

  def portfolio_evidence_path=(value)
    # Strip the student work directory to store in database as relative path
    self.portfolio_evidence = value.present? ? value.sub(FileHelper.student_work_dir, '') : nil
  end

  # The path to the PDF for this task's submission
  def final_pdf_path
    if group_task?
      return nil if group_submission.nil? || group_submission.task_definition.nil?

      File.join(
        FileHelper.student_group_work_dir(:pdf, group_submission, task = nil, create = true),
        FileHelper.sanitized_filename(FileHelper.sanitized_path("#{group_submission.task_definition.abbreviation}-#{group_submission.id}") + '.pdf')
      )
    else
      File.join(student_work_dir(:pdf), FileHelper.sanitized_filename(FileHelper.sanitized_path("#{task_definition.abbreviation}-#{id}") + '.pdf'))
    end
  end

  # Convert a submission to pdf - the source folder is the root folder in which the submission folder will be found (not the submission folder itself)
  def convert_submission_to_pdf(source_folder = FileHelper.student_work_dir(:new))
    return false unless move_files_to_in_process(source_folder)

    begin
      tac = TaskAppController.new
      tac.init(self, false)

      begin
        pdf_text = tac.make_pdf
      rescue => e
        # Try again... with convert to ascic
        #
        tac2 = TaskAppController.new
        tac2.init(self, true)

        begin
          pdf_text = tac2.make_pdf
        rescue => e2
          logger.error "Failed to create PDF for task #{log_details}. Error: #{e.message}"

          log_file = e.message.scan(/\/.*\.log/).first
          # puts "log file is ... #{log_file}"
          if log_file && File.exist?(log_file)
            # puts "exists"
            begin
              puts "--- Latex Log ---\n"
              puts File.read(log_file)
              puts "---    End    ---\n\n"
            rescue
            end
          end

          raise 'Failed to convert your submission to PDF. Check code files submitted for invalid characters, that documents are valid pdfs, and that images are valid.'
        end
      end

      # save the final pdf path to portfolio evidence - relative to student work folder
      if group_task?
        group_submission.tasks.each do |t|
          t.portfolio_evidence_path = final_pdf_path
          t.save
        end
        reload
      else
        self.portfolio_evidence_path = final_pdf_path
      end

      # Save the file... now using the full path!
      File.open(portfolio_evidence_path, 'w') do |fout|
        fout.puts pdf_text
      end

      FileHelper.compress_pdf(portfolio_evidence_path)

      # if the task is the draft learning summary task
      if task_definition_id == unit.draft_task_definition_id
        # if there is a learning summary, execute, if there isn't and a learning summary exists, don't execute
        if project.uses_draft_learning_summary || !project.learning_summary_report_exists?
          project.save_as_learning_summary_report portfolio_evidence_path
        end
      end

      save

      clear_in_process
      return true
    rescue => e
      clear_in_process

      trigger_transition trigger: 'fix', by_user: project.tutor_for(task_definition)
      raise e
    end
  end

  #
  # The student has uploaded new work...
  #
  def create_submission_and_trigger_state_change(user, propagate = true, contributions = nil, trigger = 'ready_for_feedback', initial_task = nil)
    if group_task? && propagate
      if contributions.nil? # even distribution
        contribs = group.projects.map { |proj| { project: proj, pct: 100 / group.projects.count, pts: 3 } }
      else
        contribs = contributions.map { |data| { project: Project.find(data[:project_id]), pct: data[:pct].to_i, pts: data[:pts].to_i } }
      end
      group_submission = group.create_submission self, "#{user.name} has submitted work", contribs
      group_submission.tasks.each { |t| t.create_submission_and_trigger_state_change(user, false, contributions, trigger, self) }
      reload
    else
      self.file_uploaded_at = Time.zone.now
      self.submission_date = Time.zone.now

      # This task is now ready to submit - trigger a transition if not in final state
      unless discuss_or_demonstrate? || complete? || feedback_exceeded? || fail?
        trigger_transition trigger: trigger, by_user: user, group_transition: group_task? && initial_task != self
      end

      # Destroy the links to ensure we test new files
      task_similarities.each(&:destroy)
      reverse_task_similarities(&:destroy)

      save
    end
  end

  #
  # Create alignments on submission
  #
  def create_alignments_from_submission(alignments)
    # Remove existing alignments no longer applicable
    LearningOutcomeTaskLink.where(task_id: id).delete_all()
    alignments.each do |alignment|
      link = LearningOutcomeTaskLink.find_or_create_by(
        task_definition_id: task_definition.id,
        learning_outcome_id: alignment[:ilo_id],
        task_id: id
      )
      link.rating = alignment[:rating]
      link.description = alignment[:rationale]
      link.save!
    end
  end

  #
  # Moves submission into place
  # - from -- tmp upload files
  # - to "in_process" folder
  #
  # Checks to make sure that the files match what we expect
  #
  def accept_submission(current_user, files, _student, ui, contributions, trigger, alignments, accepted_tii_eula: false)
    #
    # Ensure that each file in files has the following attributes:
    # id, name, filename, type, tempfile
    #
    files.each do |file|
      ui.error!({ 'error' => "Missing file data for '#{file[:name]}'" }, 403) if file[:id].nil? || file[:name].nil? || file[:filename].nil? || file[:type].nil? || file["tempfile"].nil?
    end

    # Ensure group if group task
    if group_task? && group.nil?
      ui.error!({ 'error' => 'You must be in a group to submit this task.' }, 403)
    end

    # Ensure not already submitted if group task
    if group_task? && group_submission && group_submission.processing_pdf? && group_submission.submitter_task != self
      ui.error!({ 'error' => "#{group_submission.submitter_task.project.student.name} has just submitted this task. Only one team member needs to submit this task, so check back soon to see what was uploaded." }, 403)
    end
    # file[:key]            = "file0"
    # file[:name]           = front end name for file
    # file["tempfile"].path  = actual file dir
    # file[:filename]       = their name for the file

    #
    # Confirm subtype categories using filemagic
    #
    files.each_with_index do |file, index|
      logger.debug "Accepting submission (file #{index + 1} of #{files.length}) - checking file type for #{file["tempfile"].path}"
      unless FileHelper.accept_file(file, file[:name], file[:type])
        ui.error!({ 'error' => "'#{file[:name]}' is not a valid #{file[:type]} file" }, 403)
      end

      if File.size(file["tempfile"].path) > 10_000_000
        ui.error!({ 'error' => "'#{file[:name]}' exceeds the 10MB file limit. Try compressing or reformat and submit again." }, 403)
      end
    end

    # Ready to accept... so create the submission and update the task status
    create_submission_and_trigger_state_change(current_user, true, contributions, trigger, self)

    # Update the alignments - across groups if needed
    unless alignments.nil?
      if group_task?
        ensured_group_submission.propogate_alignments_from_submission(alignments)
      else
        create_alignments_from_submission(alignments)
      end
    end

    #
    # Create student submission folder (<tmpdir>/doubtfire/new/<id>)
    #
    tmp_dir = File.join(Dir.tmpdir, 'doubtfire', 'new', id.to_s)
    logger.debug "Creating temporary directory for new submission at #{tmp_dir}"

    # ensure the dir exists
    FileUtils.mkdir_p(tmp_dir)

    #
    # Set portfolio_evidence_path to nil while it gets processed
    #
    self.portfolio_evidence_path = nil

    files.each_with_index.map do |file, idx|
      output_filename = File.join(tmp_dir, "#{idx.to_s.rjust(3, '0')}-#{file[:type]}#{File.extname(file[:filename]).downcase}")
      FileUtils.cp file["tempfile"].path, output_filename
    end

    #
    # Now copy over the temp directory over to the enqueued directory (in process)
    #
    enqueued_dir = File.join(FileHelper.student_work_dir(:new, nil, true), id.to_s)

    # Move files into place, deleting existing files if present.
    if not File.exist? enqueued_dir
      logger.debug "Creating student work new dir #{enqueued_dir}"
      FileUtils.mkdir_p enqueued_dir
    end

    # Move files into place
    logger.debug "Moving source files from #{tmp_dir} into #{enqueued_dir}"
    FileUtils.mv Dir.glob(File.join(tmp_dir, '*.*')), enqueued_dir, force: true

    # Delete the tmp dir
    logger.debug "Deleting student work dir: #{tmp_dir}"
    FileUtils.rm_rf tmp_dir

    logger.info "Submission accepted! Status for task #{id} is now #{trigger}"

    # Trigger processing of new submission - async
    AcceptSubmissionJob.perform_async(id, current_user.id, accepted_tii_eula)
  end

  # The name that should be used for the uploaded file (based on index of upload requirements)
  # @param idx The index of the upload requirement to get the filename for
  def filename_for_upload(idx)
    return nil unless idx >= 0 && idx < upload_requirements.length
    "#{upload_requirements[idx]['name']}#{extension_for_upload(idx)}"
  end

  def extension_for_upload(idx)
    filename = filename_in_zip(idx)
    return nil if filename.nil?

    dot_idx = filename.index('.')
    return '' if dot_idx.nil?
    filename[dot_idx..-1]
  end

  def filename_in_zip(idx)
    path = FileHelper.zip_file_path_for_done_task(self)
    return nil unless File.exist? path
    return nil unless idx >= 0 && idx < upload_requirements.length

    type = upload_requirements[idx]['type']

    required_filename_start = "#{id}/#{idx.to_s.rjust(3, '0')}-#{type}"

    Zip::File.open(path) do |zip_file|
      zip_file.each do |entry|
        next unless entry.name.starts_with?(required_filename_start)
        return entry.name.remove("#{id}/")
      end
    end

    nil
  end

  delegate :number_of_uploaded_files, :number_of_documents, :is_document?, :use_tii?, :tii_match_pct, to: :task_definition

  def read_file_from_done(idx)
    path = FileHelper.zip_file_path_for_done_task(self)
    return nil unless File.exist? path
    return nil unless idx >= 0 && idx < upload_requirements.length

    type = upload_requirements[idx]['type']

    required_filename_start = "#{id}/#{idx.to_s.rjust(3, '0')}-#{type}"

    Zip::File.open(path) do |zip_file|
      zip_file.each do |entry|
        next unless entry.name.starts_with?(required_filename_start)

        result = ''
        # Read into memory
        entry.get_input_stream { |io| result = io.read }

        return result
      end
    end
    # we got to the end so no match
    nil
  end

  private

  def delete_associated_files
    if group_submission && group_submission.tasks.count <= 1
      group_submission.destroy
    else
      zip_file = zip_file_path_for_done_task

      FileUtils.rm(zip_file) if zip_file && File.exist?(zip_file)

      FileUtils.rm(portfolio_evidence_path) if portfolio_evidence_path.present? && File.exist?(portfolio_evidence_path)

      new_path = FileHelper.student_work_dir(:new, self, false)
      FileUtils.rm_rf(new_path) if new_path.present? && File.directory?(new_path)
    end
  end

  # Use the current DateTime to calculate a new DateTime for the last moment of the same
  # day anywhere on earth
  def to_same_day_anywhere_on_earth(date)
    DateTime.new(date.year, date.month, date.day, 23, 59, 59, '-12:00')
  end
end
