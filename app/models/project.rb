class Float
  def signif(signs)
    Float("%.#{signs}f" % self)
  end
end

class Integer
  def signif(signs)
    Float(self)
  end
end

class Project < ApplicationRecord
  include ApplicationHelper
  include DbHelpers

  include PdfGeneration::ProjectCompilePortfolioModule

  belongs_to :unit, optional: false
  belongs_to :user, optional: false
  belongs_to :campus, optional: true

  # has_one :user, through: :student
  has_many :tasks, dependent: :destroy # Destroying a project will also nuke all of its tasks
  has_many :group_memberships, dependent: :destroy
  has_many :tutorial_enrolments, dependent: :destroy

  has_many :groups, -> { where('group_memberships.active = :value', value: true) }, through: :group_memberships
  has_many :task_engagements, through: :tasks
  has_many :comments, through: :tasks
  has_many :learning_outcome_task_links, through: :tasks

  # Callbacks - methods called are private
  before_destroy :can_destroy?

  validates :grade_rationale, length: { maximum: 4095, allow_blank: true }

  validate :tutorial_enrolment_same_campus, if: :will_save_change_to_enrolled?

  after_update :check_withdraw_from_groups, if: :saved_change_to_enrolled?
  after_update :update_task_stats, if: :saved_change_to_target_grade? # TODO: consider making this an async task!

  #
  # Permissions around project data
  #
  def self.permissions
    # What can students do with projects?
    student_role_permissions = [
      :get,
      :make_submission,
      :get_submission,
      :change
    ]
    # What can tutors do with projects?
    tutor_role_permissions = [
      :get,
      :trigger_week_end,
      :change_tutorial,
      :make_submission,
      :get_submission,
      :change,
      :assess,
      :change_campus
    ]
    # What can admins do with projects?
    admin_role_permissions = [
      :get,
      :get_submission
    ]
    # What can auditors do with projects?
    auditor_role_permissions = [
      :get,
      :get_submission
    ]
    # What can nil users do with projects?
    nil_role_permissions = []

    # Return permissions hash
    {
      student: student_role_permissions,
      tutor: tutor_role_permissions,
      admin: admin_role_permissions,
      auditor: auditor_role_permissions,
      nil: nil_role_permissions
    }
  end

  def role_for(user)
    user_role(user)
  end

  # Get all of the projects for the indicated user - with or without inactive units
  def self.for_user(user, include_inactive)
    # Limit to enrolled units... for this user
    result = where(enrolled: true).where('projects.user_id = :user_id', user_id: user.id)

    # Return the result if we include inactive units...
    return result if include_inactive

    # Otherwise link in units and only get active units
    result.joins(:unit).where('units.active = TRUE')
  end

  # Used to adjust the change tutorial permission in units that do not
  # allow students to change tutorials
  def specific_permission_hash(role, perm_hash, _other)
    result = perm_hash[role] unless perm_hash.nil?
    if result && role == :student && unit.allow_student_change_tutorial
      result << :change_tutorial
    end
    result
  end

  def enrol_in(tutorial)
    tutorial_enrolment = matching_enrolment(tutorial)
    return tutorial_enrolment if tutorial_enrolment.present? && tutorial_enrolment.tutorial_id == tutorial.id

    # Check if multiple enrolments changing to a single enrolment - due to no stream.
    # No need to delete if only 1, as that would be updated as well.
    if tutorial_enrolments.count > 1 && tutorial.tutorial_stream.nil?
      begin
        # So remove current enrolments
        tutorial_enrolments.destroy_all()
        # and there is no longer an associated tutorial enrolment
        tutorial_enrolment = nil
      rescue ActiveRecord::RecordNotDestroyed => e
        raise ActiveRecord::RecordNotDestroyed.new("Unable to change tutorial due to group enrolment in current tutorials.", e.record)
      end
    end

    if tutorial_enrolment.nil?
      tutorial_enrolment = TutorialEnrolment.new
      tutorial_enrolment.tutorial = tutorial
      tutorial_enrolment.project = self

      # Add this enrolment to aid and check project validation
      tutorial_enrolments << tutorial_enrolment

      tutorial_enrolment.save!

      # add after save to ensure valid tutorial_enrolments
      self.tutorial_enrolments << tutorial_enrolment
    else # there is an existing enrolment...
      tutorial_enrolment.tutorial = tutorial
      tutorial_enrolment.update!(tutorial_id: tutorial.id)
    end
    tutorial_enrolment
  end

  def enrolled_in?(tutorial)
    tutorial_enrolments.select { |e| e.tutorial_id == tutorial.id }.count > 0 || tutorial_enrolments.where(tutorial_id: tutorial.id).count > 0
  end

  # Find enrolment in same tutorial stream
  def matching_enrolment(tutorial)
    tutorial_enrolments
      .joins(:tutorial)
      .where('tutorials.tutorial_stream_id = :sid OR tutorials.tutorial_stream_id IS NULL OR :sid IS NULL', sid: tutorial.tutorial_stream_id)
      .first
  end

  # Check tutorial membership if there is a campus change
  def tutorial_enrolment_same_campus
    return unless enrolled && campus_id.present? && will_save_change_to_campus_id?

    if tutorial_enrolments.joins(:tutorial).where('tutorials.campus_id <> :cid', cid: campus_id).count > 0
      errors.add(:campus, "does not match with tutorial enrolments.")
    end
  end

  def log_details
    "#{id} - #{student.name} (#{student.username}) #{unit.code}"
  end

  def task_outcome_alignments
    learning_outcome_task_links
  end

  #
  # All "discuss" and "demonstrate" become complete
  #
  def trigger_week_end(by_user)
    discuss_and_demonstrate_tasks.each { |task| task.trigger_transition(trigger: 'complete', by_user: by_user, bulk: true, quality: task.quality_pts) }
  end

  def student
    user
  end

  def tutors_and_tutorial
    current_tutor = nil
    first_tutor = true

    tutorial_enrolments
      .joins(tutorial: { unit_role: :user })
      .order('tutor')
      .select("tutorials.abbreviation as tutorial_abbr, #{db_concat('users.first_name', "' '", 'users.last_name')} as tutor")
      .map do |t|
        result = "#{t.tutor == current_tutor ? '' : "#{first_tutor ? '' : ') '}#{t.tutor} ("}#{t.tutorial_abbr}"
        current_tutor = t.tutor
        first_tutor = false
        result
      end.join(' ') + (first_tutor ? '' : ')')
  end

  def tutorial_enrolment_for_stream(tutorial_stream)
    tutorial_enrolments
      .joins(:tutorial)
      .where('tutorials.tutorial_stream_id = :sid OR tutorials.tutorial_stream_id IS NULL', sid: (tutorial_stream.present? ? tutorial_stream.id : nil))
      .first
  end

  def tutorial_for_stream(tutorial_stream)
    enrolment = tutorial_enrolment_for_stream(tutorial_stream)
    enrolment.tutorial unless enrolment.nil?
  end

  def tutorial_for(task_definition)
    tutorial_for_stream(task_definition.tutorial_stream) unless task_definition.nil?
  end

  def tutor_for(task_definition)
    tutorial = tutorial_for(task_definition)
    (tutorial.present? and tutorial.tutor.present?) ? tutorial.tutor : main_convenor_user
  end

  delegate :main_convenor_user, to: :unit

  def user_role(user)
    if user == student then :student
    elsif user.present? && unit.tutors.where(id: user.id).count != 0 then :tutor
    elsif user.present? && user.role.id == Role.admin_id then :admin
    elsif user.present? && user.role.id == Role.auditor_id then :auditor
    else nil
    end
  end

  def active?
    unit.active
  end

  #
  # Get a string representation of the Target Grade
  #
  def target_grade_desc
    case target_grade
    when 1
      'Credit'
    when 2
      'Distinction'
    when 3
      'High Distinction'
    else
      'Pass'
    end
  end

  def reference_date
    [application_reference_date, unit.end_date].min
  end

  def task_details_for_shallow_serializer(user)
    tasks
      .joins(:task_status)
      .joins("LEFT JOIN task_comments ON task_comments.task_id = tasks.id AND (task_comments.type IS NULL OR task_comments.type <> 'TaskStatusComment')")
      .joins("LEFT JOIN comments_read_receipts crr ON crr.task_comment_id = task_comments.id AND crr.user_id = #{user.id}")
      .joins('LEFT OUTER JOIN task_similarities ON tasks.id = task_similarities.task_id')
      .select(
        'SUM(case when crr.user_id is null AND NOT task_comments.id is null then 1 else 0 end) as number_unread', 'project_id', 'tasks.id as id',
        'task_definition_id', 'task_statuses.id as status_id',
        'completion_date', 'times_assessed', 'submission_date', 'tasks.grade as grade', 'quality_pts', 'include_in_portfolio', 'grade',
        'SUM(case when task_similarities.flagged then 1 else 0 end) as similar_to_count'
      )
      .group(
        'task_statuses.id', 'tasks.project_id', 'tasks.id', 'task_definition_id', 'status_id',
        'completion_date', 'times_assessed', 'submission_date', 'grade', 'quality_pts',
        'include_in_portfolio', 'grade'
      )
      .map do |r|
        t = Task.find(r.id)
        {
          id: r.id,
          status: TaskStatus.id_to_key(r.status_id),
          task_definition_id: r.task_definition_id,
          include_in_portfolio: r.include_in_portfolio,
          times_assessed: r.times_assessed,
          grade: r.grade,
          quality_pts: r.quality_pts,
          num_new_comments: r.number_unread,
          similarity_flag: AuthorisationHelpers.authorise?(user, t, :view_plagiarism) ? r.similar_to_count > 0 : false,
          extensions: t.extensions,
          due_date: t.due_date,
          submission_date: t.submission_date,
          completion_date: t.completion_date
        }
      end
  end

  def assigned_tasks
    tasks.joins(:task_definition).where('task_definitions.target_grade <= :target', target: target_grade)
  end

  def target_grade=(value)
    self[:target_grade] = value
  end

  #
  # Get task_definitions and status for the current student for all tasks that are <= the target
  #
  def task_definitions_and_status(target)
    assigned_task_defs_for_grade(target)
      .order("start_date ASC, abbreviation ASC")
      .map { |td|
      if has_task_for_task_definition? td
        task = task_for_task_definition(td)
        { task_definition: td, task: task, status: task.status }
      else
        { task_definition: td, task: nil, status: :not_started }
      end
    }
      .select { |r| [:not_started, :redo, :need_help, :working_on_it, :fix_and_resubmit, :demonstrate, :discuss].include? r[:status] }
  end

  #
  # Calculate a list of the top 5 task definitions the student should focus on,
  # in order of priority with reason.
  #
  def top_tasks
    result = []

    to_target = lambda { |ts| ts[:task].nil? ? ts[:task_definition].target_date : ts[:task].due_date }

    #
    # Get list of tasks that could be top tasks...
    #
    task_states = task_definitions_and_status(target_grade)

    #
    # Start with overdue...
    #
    overdue_tasks = task_states.select { |ts| to_target.call(ts) < Time.zone.today }

    grades = ["Pass", "Credit", "Distinction", "High Distinction"]

    for i in GradeHelper::RANGE
      graded_tasks = overdue_tasks.select { |ts| ts[:task_definition].target_grade == i  }

      graded_tasks.each do |ts|
        result << { task_definition: ts[:task_definition], status: ts[:status], reason: :overdue }
      end

      # pick the top 5
      return result.slice(0..4) if result.count >= 5
    end

    #
    # Add in soon tasks...
    #
    soon_tasks = task_states.select { |ts| to_target.call(ts) >= Time.zone.today && to_target.call(ts) < Time.zone.today + 7.days }

    for i in GradeHelper::RANGE
      graded_tasks = soon_tasks.select { |ts| ts[:task_definition].target_grade == i }

      graded_tasks.each do |ts|
        result << { task_definition: ts[:task_definition], status: ts[:status], reason: :soon }
      end

      return result.slice(0..4) if result.count >= 5
    end

    #
    # Add in ahead tasks...
    #
    ahead_tasks = task_states.select { |ts| to_target.call(ts) >= Time.zone.today + 7.days }

    for i in GradeHelper::RANGE
      graded_tasks = ahead_tasks.select { |ts| ts[:task_definition].target_grade == i }

      graded_tasks.each do |ts|
        result << { task_definition: ts[:task_definition], status: ts[:status], reason: :ahead }
      end

      return result.slice(0..4) if result.count >= 5
    end

    result.slice(0..4)
  end

  def should_revert_to_pass
    return false unless self.target_grade > 0

    to_target = lambda { |ts| ts[:task].nil? ? ts[:task_definition].target_date.to_date : ts[:task].due_date.to_date }

    task_states = task_definitions_and_status(0)
    overdue_tasks = task_states.select { |ts| to_target.call(ts) < Time.zone.today }

    # More than 2 pass tasks overdue
    return false unless overdue_tasks.count > 2

    # Oldest is more than 2 weeks past target
    return false unless (Time.zone.today - to_target.call(overdue_tasks.first)).to_i >= 14

    return true
  end

  def weeks_elapsed(date = nil)
    (days_elapsed(date) / 7.0).ceil
  end

  def days_elapsed(date = nil)
    date ||= reference_date
    (date - unit.start_date).to_i / 1.day
  end

  def weekly_completion_rate(date = nil)
    # Return a completion rate of 0.0 if the project is yet to have commenced
    return 0.0 if ready_or_complete_tasks.empty?

    date ||= reference_date

    weeks = weeks_elapsed(date)
    # Ensure at least one week
    weeks = 1 if weeks < 1

    completed_tasks_weight / weeks.to_f
  end

  def completed_tasks
    assigned_tasks.select(&:complete?)
  end

  def ready_or_complete_tasks
    assigned_tasks.select(&:ready_or_complete?)
  end

  def tasks_in_submitted_status
    assigned_tasks.select(&:submitted_status?)
  end

  def discuss_and_demonstrate_tasks
    tasks.select(&:discuss_or_demonstrate?)
  end

  #
  # get the weight of all tasks completed or marked as ready to assess
  #
  def completed_tasks_weight
    ready_or_complete_tasks.empty? ? 0.0 : ready_or_complete_tasks.map { |task| task.task_definition.weighting }.inject(:+)
  end

  def convert_hash_to_pct(hash, total)
    hash.each { |key, value| hash[key] = (hash[key] < 0.01 ? 0.0 : (value / total).signif(2)) }

    total = 0.0
    hash.each_value { |value| total += value }

    if total != 1.0
      dif = 1.0 - total
      hash.each do |key, value|
        if value > 0.0
          hash[key] = (hash[key] + dif).signif(2)
          break
        end
      end
    end
  end

  DEFAULT_TASK_STATS = {
    red_pct: 0,
    grey_pct: 1,
    orange_pct: 0,
    blue_pct: 0,
    green_pct: 0,
    order_scale: 0
  }.freeze

  # Calculate the task stats text to send progress data back to the client
  # Total task counts must contain an array of the cummulative task counts (with none being 0)
  # Project task counts is an object with fail_count, complete_count etc for each status
  def self.create_task_stats_from(total_task_counts, project_task_counts, target_grade)
    # check there are tasks...
    if total_task_counts[target_grade] > 0
      # For each kind of task status... get counts of that status from the passed project stats
      (1..TaskStatus.count).each do |status_id|
        project_task_counts["#{TaskStatus.id_to_key(status_id)}_count"] = 0 if project_task_counts["#{TaskStatus.id_to_key(status_id)}_count"].nil?
      end

      red_pct = ((project_task_counts.fail_count + project_task_counts.feedback_exceeded_count + project_task_counts.time_exceeded_count) / total_task_counts[target_grade]).signif(2)
      orange_pct = ((project_task_counts.redo_count + project_task_counts.need_help_count + project_task_counts.fix_and_resubmit_count) / total_task_counts[target_grade]).signif(2)
      green_pct = ((project_task_counts.discuss_count + project_task_counts.demonstrate_count + project_task_counts.complete_count) / total_task_counts[target_grade]).signif(2)
      blue_pct = (project_task_counts.ready_for_feedback_count / total_task_counts[target_grade]).signif(2)
      grey_pct = (1 - red_pct - orange_pct - green_pct - blue_pct).signif(2)

      order_scale = (green_pct * 100) + (blue_pct * 100) + (orange_pct * 10) - red_pct
    else
      red_pct = 0
      orange_pct = 0
      green_pct = 0
      blue_pct = 0
      grey_pct = 1
      order_scale = 0
    end

    {
      red_pct: red_pct,
      grey_pct: grey_pct,
      orange_pct: orange_pct,
      blue_pct: blue_pct,
      green_pct: green_pct,
      order_scale: order_scale
    }
  end

  # Recalculate the task stats for the project, and store in the
  # task_stats field
  def update_task_stats
    # generate SQL for columns that count the number of tasks per grade
    count_by_grade = (GradeHelper::RANGE).map { |grade_id| "SUM(CASE WHEN target_grade <= #{grade_id} THEN 1 ELSE 0 END) AS count_#{grade_id}" }

    # Get the count of the total number of tasks less than each target grade
    task_count = unit
                 .task_definitions
                 .select(*count_by_grade) # create columns for each grade
                 .map do |r| # map to array
      [
        r['count_0'].to_f || 0.0,
        r['count_1'].to_f || 0.0,
        r['count_2'].to_f || 0.0,
        r['count_3'].to_f || 0.0
      ]
    end
                 .first # there is only one row returned...

    # Generate SQL to get the count of each task status for the project
    sum_by_status = (1..TaskStatus.count).map do |status_id|
      "SUM(CASE WHEN tasks.task_status_id = #{status_id} THEN 1 ELSE 0 END) AS #{TaskStatus.id_to_key(status_id)}_count"
    end

    # Get the assigned tasks (those where task grade <= target grade)
    # sum the task counts by status
    # and map to json from tasks stats
    # getting first... as there is only one row returned (the row with sums)
    result = assigned_tasks
             .select(*sum_by_status)
             .map { |t| Project.create_task_stats_from(task_count, t, target_grade) }
             .first

    # There may be no row however... in which case use the defaults
    if result.nil?
      result = DEFAULT_TASK_STATS
    else
      result
    end

    update(task_stats: result.to_json)
  end

  def assigned_task_defs_for_grade(target)
    unit.task_definitions.where('target_grade <= :grade', grade: target)
  end

  def assigned_task_defs
    assigned_task_defs_for_grade target_grade
  end

  def total_task_weight
    assigned_task_defs.map(&:weighting).inject(:+)
  end

  def remaining_days
    (unit.end_date - reference_date).to_i / 1.day
  end

  def in_progress?
    commenced? && !concluded?
  end

  def commenced?
    application_reference_date >= unit.start_date
  end

  def concluded?
    application_reference_date > unit.end_date
  end

  def last_task_completed
    completed_tasks.sort_by(&:completion_date).last
  end

  def matching_task(other_task)
    task_for_task_definition(other_task.task_definition)
  end

  def has_task_for_task_definition?(td)
    !tasks.where(task_definition: td).first.nil?
  end

  #
  # Get the status of a task, without creating it if it does not exist...
  #
  def status_for_task_definition(td)
    if has_task_for_task_definition? td
      task_for_task_definition(td).status
    else
      :not_started
    end
  end

  #
  # Get the task for the requested definition. This will create the
  # task if the task does not exist for this project.
  #
  def task_for_task_definition(td)
    logger.debug "Finding task #{td.abbreviation} for project #{log_details}"
    result = tasks.where(task_definition: td).first
    if result.nil?
      begin
        result = Task.create!(
          task_definition_id: td.id,
          project_id: id,
          task_status_id: 1
        )
        logger.info "Created task #{result.id} - #{td.abbreviation} for project #{log_details}"
        result.save
        tasks.push result
      rescue
        result = tasks.where(task_definition: td).first
      end
    end
    result
  end

  def group_for_groupset(gs)
    groups.where(group_set: gs).first
  end

  def group_membership_for_groupset(gs)
    group_memberships.joins(:group).where('groups.group_set_id = :id', id: gs).first
  end

  def export_task_alignment_to_csv
    LearningOutcomeTaskLink.export_task_alignment_to_csv(unit, self)
  end

  def send_weekly_status_email(summary_stats, middle_of_unit)
    did_revert_to_pass = false
    if middle_of_unit && should_revert_to_pass && !portfolio_exists?
      self.target_grade = 0
      save
      did_revert_to_pass = true

      summary_stats[:revert_count] = summary_stats[:revert_count] + 1
      summary_stats[:revert][main_convenor_user] << self
    end

    return unless student.receive_feedback_notifications
    return if portfolio_exists? && !middle_of_unit

    NotificationsMailer.weekly_student_summary(self, summary_stats, did_revert_to_pass).deliver_now
  end

  def archive_submissions(out)
    out.puts " - Archiving submissions for project #{id}"
    tasks.each(&:archive_submission)

    FileUtils.rm_f(portfolio_path) if portfolio_available
  end

  private

  def can_destroy?
    return true if tutorial_enrolments.count == 0

    errors.add :base, "Cannot delete project with enrolments"
    throw :abort
  end

  # If someone withdraws from a unit, make sure they are removed from groups
  def check_withdraw_from_groups
    # return if enrolled was not changed... or we are now not enrolled
    return unless enrolled && !saved_change_to_enrolled[0] # 0 is the old value of enrolled before update

    group_memberships.each do |gm|
      next unless gm.active

      if gm.invalid? || gm.group.beyond_capacity?
        gm.update(active: false)
      end
    end
  end
end
