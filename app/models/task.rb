class Task < ActiveRecord::Base
  include ApplicationHelper

  def self.permissions
    { 
      student: [ :get, :put, :get_submission, :make_submission, :delete_own_comment ],
      tutor: [ :get, :put, :get_submission, :make_submission, :delete_other_comment, :delete_own_comment, :view_plagiarism ],
      convenor: [ :get, :get_submission, :make_submission, :delete_other_comment, :delete_own_comment, :view_plagiarism ],
      nil => []
    }
  end

  def role_for(user)
    project_role = project.user_role(user)
    return project_role unless project_role.nil?
    # puts "getting role... #{task_definition.abbreviation} #{task_definition.group_set}"
    # check for group member
    if group_task?
      # puts "checking group"
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
  has_many :sub_tasks,      dependent: :destroy
  has_many :comments, class_name: "TaskComment", dependent: :destroy, inverse_of: :task
  has_many :plagarism_match_links, class_name: "PlagiarismMatchLink", dependent: :destroy, inverse_of: :task
  has_many :reverse_plagiarism_match_links, class_name: "PlagiarismMatchLink", dependent: :destroy, inverse_of: :other_task, foreign_key: "other_task_id"
  belongs_to :group_submission

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
    Task.joins(project: :unit_role).where("unit_roles.user_id = ?", user.id)
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
    task_definition.target_date
  end

  def complete?
    status == :complete
  end

  def discuss?
    status == :discuss
  end
  
  def ok_to_submit?
    status != :complete && status != :discuss
  end

  def ready_to_mark?
    status == :ready_to_mark
  end

  def ready_or_complete?
    status == :complete || status == :discuss || status == :ready_to_mark
  end

  def fix_and_resubmit?
    status == :fix_and_resubmit
  end

  def fix_and_include?
    status == :fix_and_include
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
      # puts "Assigning #{id} = #{final_pdf_path}"
      self.portfolio_evidence = final_pdf_path
      # puts "Path is now #{id} = #{self.portfolio_evidence}"
      self.save
    end
  end

  def group_task?
    (not group_submission.nil?) || (not task_definition.group_set.nil?)
  end

  def group
    return nil unless group_task?
    return group_submission.group unless group_submission.nil?
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
    # puts "#{role} #{group_transition}"
    return nil if role.nil?

    #
    # Ensure that only staff can change from staff assigned status if
    # this is a restricted task
    #
    return nil if [ :student, :group_member ].include?(role) && 
                  task_definition.restrict_status_updates && 
                  self.task_status.in?([ TaskStatus.redo, TaskStatus.complete, TaskStatus.fix_and_resubmit, 
                    TaskStatus.fix_and_include, TaskStatus.discuss ])
    
    #
    # State transitions based upon the trigger
    #

    #
    # Tutor and student can trigger these actions...
    #
    case trigger
      when "ready_to_mark", "rtm"
        submit
      when "not_submitted"
        engage TaskStatus.not_submitted
      when "not_ready_to_mark"
        engage TaskStatus.not_submitted
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
            when "redo"
              assess TaskStatus.redo, by_user
            when "complete"
              assess TaskStatus.complete, by_user
            when "fix_and_resubmit", "fix", "f"
              assess TaskStatus.fix_and_resubmit, by_user
            when "fix_and_include", "fixinc"
              assess TaskStatus.fix_and_include, by_user
            when "discuss", "d"
              assess TaskStatus.discuss, by_user
          end
        end
    end

    if (not group_transition) && group_task?
      # puts "#{group_transition} #{group_submission} #{trigger} #{id}"
      if not [ TaskStatus.working_on_it, TaskStatus.need_help  ].include? task_status
        ensured_group_submission.propagate_transition self, trigger, by_user
      end
    end

    if not bulk then project.calc_task_stats(self) end
  end

  def assess(task_status, assessor)
    # Set the task's status to the assessment outcome status
    # and flag it as no longer awaiting signoff
    self.task_status       = task_status
    self.awaiting_signoff  = false

    # Set the completion date of the task if it's been completed
    if ready_or_complete?
      if completion_date.nil?
        self.completion_date = Time.zone.now
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
        submission_attributes = {task: self, assessment_time: Time.zone.now, assessor: assessor, outcome: task_status.name}

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
    return if [ :complete ].include? task_status.status_key

    self.task_status       = engagement_status
    self.awaiting_signoff  = false
    self.completion_date   = nil

    if save!
      project.start
      TaskEngagement.create!(task: self, engagement_time: Time.zone.now, engagement: task_status.name)
    end
  end

  def submit
    return if [ :complete ].include? task_status.status_key

    self.task_status      = TaskStatus.ready_to_mark
    self.awaiting_signoff = true
    self.completion_date  = Time.zone.now

    if save!
      project.start
      submission = TaskSubmission.where(task_id: self.id).order(:submission_time).reverse_order.first

      if submission.nil?
        TaskSubmission.create!(task: self, submission_time: Time.zone.now)
      else
        if !submission.submission_time.nil? && submission.submission_time < 1.hour.since(Time.zone.now)
          submission.submission_time = Time.zone.now
          submission.save!
        else
          TaskSubmission.create!(task: self, submission_time: Time.zone.now)
        end
      end
    end
  end

  def assessed?
    redo? ||
    fix_and_resubmit? ||
    fix_and_include? ||
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

  def last_comment_by(user)
    result = all_comments.where(user: user).last
    
    return '' if result.nil?
    result.comment
  end

  def last_comment_not_by(user)
    result = all_comments.where("user_id != :id", id: user.id).last
    
    return '' if result.nil?
    result.comment
  end

  # Indicates what is the largest % similarity is for this task
  def pct_similar
    if plagarism_match_links.order(pct: :desc).first.nil?
      0
    else
      plagarism_match_links.order(pct: :desc).first.pct
    end
  end

  def similar_to_count
    plagarism_match_links.count
  end

  #
  # The student has uploaded new work...
  #
  def accept_new_submission (user, propagate = true, contributions = nil, trigger = 'ready_to_mark')
    if group_task? && propagate
      if contributions.nil? # even distribution
        contribs = group.projects.map { |proj| { project: proj, pct: 100 / group.projects.count }  }
      else
        contribs = contributions.map { |data| { project: Project.find(data[:project_id]), pct: data[:pct].to_i }  }
        # puts contribs
      end
      group_submission = group.create_submission self, "#{user.name} has submitted work", contribs
      group_submission.tasks.each { |t| t.accept_new_submission(user, propagate=false) }
      reload
    else
      self.file_uploaded_at = DateTime.now

      # This task is now ready to submit
      if not (discuss? || complete? || fix_and_include?)
        self.trigger_transition trigger, user, false, false # dont propagate -- already done
        
        plagarism_match_links.each do | link |
          link.destroy
        end
        reverse_plagiarism_match_links do | link |
          link.destroy
        end
      end
      save
    end
  end
end


