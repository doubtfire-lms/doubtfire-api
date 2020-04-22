class Float
  def signif(signs)
    Float("%.#{signs}f" % self)
  end
end

class Fixnum
  def signif(signs)
    Float("%.#{signs}f" % self)
  end
end

class Project < ActiveRecord::Base
  include ApplicationHelper
  include LogHelper
  include DbHelpers

  belongs_to :unit
  belongs_to :user
  belongs_to :campus

  # has_one :user, through: :student
  has_many :tasks, dependent: :destroy # Destroying a project will also nuke all of its tasks

  has_many :group_memberships, dependent: :destroy
  has_many :groups, -> { where('group_memberships.active = :value', value: true) }, through: :group_memberships
  has_many :past_groups, -> { where('group_memberships.active = :value', value: false) }, through: :group_memberships, source: 'group'
  has_many :task_engagements, through: :tasks
  has_many :comments, through: :tasks
  has_many :tutorial_enrolments, dependent: :destroy

  has_many :learning_outcome_task_links, through: :tasks

  # Callbacks - methods called are private
  before_destroy :can_destroy?

  validate :must_be_in_group_tutorials
  validates :grade_rationale, length: { maximum: 4095, allow_blank: true }

  validate :tutorial_enrolment_same_campus

  #
  # Permissions around project data
  #
  def self.permissions
    # What can students do with projects?
    student_role_permissions = [
      :get,
      :change_tutorial,
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
    # What can convenors do with projects?
    convenor_role_permissions = [
    ]
    # What can nil users do with projects?
    nil_role_permissions = [
    ]

    # Return permissions hash
    {
      student: student_role_permissions,
      tutor: tutor_role_permissions,
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

  def enrol_in(tutorial)
    # Check if multiple enrolments changing to a single enrolment - due to no stream.
    # No need to delete if only 1, as that would be updated as well.
    if tutorial_enrolments.count > 1 && tutorial.tutorial_stream.nil?
      # So remove current enrolments
      tutorial_enrolments.delete_all()
    end

    tutorial_enrolment = matching_enrolment(tutorial)
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
    tutorial_enrolments.select{|e| e.tutorial_id == tutorial.id}.count > 0 || tutorial_enrolments.where(tutorial_id: tutorial.id).count > 0
  end

  # Find enrolment in same tutorial stream
  def matching_enrolment(tutorial)
    tutorial_enrolments.
      joins(:tutorial).
      where('tutorials.tutorial_stream_id = :sid OR tutorials.tutorial_stream_id IS NULL OR :sid IS NULL', sid: tutorial.tutorial_stream_id).
      first
  end

  #
  # Check to see if the student has a valid tutorial
  #
  def must_be_in_group_tutorials
    groups.each do |g|
      next unless g.limit_members_to_tutorial?
      next if enrolled_in? g.tutorial
      if g.group_set.allow_students_to_manage_groups
        # leave group
        g.remove_member(self)
      else
        errors.add(:groups, "require you to be in tutorial #{g.tutorial.abbreviation}")
        break
      end
    end
  end

  # Check tutorial membership if 
  def tutorial_enrolment_same_campus
    return unless campus_id.present? && campus_id_changed?
    return unless enrolled
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

    tutorial_enrolments.
      joins(tutorial: {unit_role: :user}).
      order('tutor').
      select("tutorials.abbreviation as tutorial_abbr, #{db_concat('users.first_name', "' '", 'users.last_name')} as tutor").
      map do |t|
        result = "#{t.tutor == current_tutor ? '' : "#{first_tutor ? '' : ') '}#{t.tutor} ("}#{t.tutorial_abbr}"
        current_tutor = t.tutor
        first_tutor = false
        result
      end.join(' ') + ( !first_tutor ? ')' : '')
  end

  def tutorial_enrolment_for_stream(tutorial_stream)
    tutorial_enrolments.
      joins(:tutorial).
      where('tutorials.tutorial_stream_id = :sid OR tutorials.tutorial_stream_id IS NULL', sid: (tutorial_stream.present? ? tutorial_stream.id : nil)).
      first
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

  def main_convenor_user
    unit.main_convenor_user
  end

  def user_role(user)
    if user == student then :student
    elsif user.nil? then nil
    elsif unit.tutors.where(id: user.id).count != 0 then :tutor
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
    if application_reference_date > unit.end_date
      unit.end_date
    else
      application_reference_date
    end
  end

  def task_details_for_shallow_serializer(user)
    tasks
      .joins(:task_status)
      .joins("LEFT JOIN task_comments ON task_comments.task_id = tasks.id")
      .joins("LEFT JOIN comments_read_receipts crr ON crr.task_comment_id = task_comments.id AND crr.user_id = #{user.id}")
      .select(
        'SUM(case when crr.user_id is null AND NOT task_comments.id is null then 1 else 0 end) as number_unread', 'project_id', 'tasks.id as id',
        'task_definition_id', 'task_statuses.id as status_id',
        'completion_date', 'times_assessed', 'submission_date', 'portfolio_evidence', 'tasks.grade as grade', 'quality_pts', 'include_in_portfolio', 'grade'
      )
      .group(
        'task_statuses.id', 'tasks.project_id', 'tasks.id', 'task_definition_id', 'status_id',
        'completion_date', 'times_assessed', 'submission_date', 'portfolio_evidence', 'grade', 'quality_pts',
        'include_in_portfolio', 'grade'
      )
      .map do |r|
        t = Task.find(r.id)
        {
          id: r.id,
          status: TaskStatus.id_to_key(r.status_id),
          task_definition_id: r.task_definition_id,
          include_in_portfolio: r.include_in_portfolio,
          pct_similar: t.pct_similar,
          similar_to_count: t.similar_to_count,
          similar_to_dismissed_count: t.similar_to_dismissed_count,
          times_assessed: r.times_assessed,
          grade: r.grade,
          quality_pts: r.quality_pts,
          num_new_comments: r.number_unread,
          extensions: t.extensions,
          due_date: t.due_date
        }
      end
  end

  def assigned_tasks
    tasks.joins(:task_definition).where('task_definitions.target_grade <= :target', target: target_grade)
  end

  def portfolio_tasks
    # Get assigned tasks that are included in the portfolio
    tasks = self.tasks.joins(:task_definition).order('task_definitions.target_date, task_definitions.abbreviation').where('tasks.include_in_portfolio = TRUE')

    # Remove the tasks that are not aligned... if there are ILOs
    unless unit.learning_outcomes.empty?
      tasks = tasks.select { |t| t.learning_outcome_task_links.count > 0 }
    end

    # Now select the tasks that and have a PDF... cant include the others...
    portfolio_tasks = tasks.select(&:has_pdf)
  end

  def target_grade=(value)
    self[:target_grade] = value
  end

  #
  # Get task_definitions and status for the current student for all tasks that are <= the target
  #
  def task_definitions_and_status(target)
    assigned_task_defs_for_grade(target).
      order("start_date ASC, abbreviation ASC").
      map { |td|
          if has_task_for_task_definition? td 
            task = task_for_task_definition(td)
            {task_definition: td, task: task, status: task.status } 
          else
            {task_definition: td, task: nil, status: :not_started } 
          end
        }.
      select { |r| [:not_started, :redo, :need_help, :working_on_it, :fix_and_resubmit, :demonstrate, :discuss].include? r[:status] }
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

    grades = [ "Pass", "Credit", "Distinction", "High Distinction" ]

    for i in 0..3
      graded_tasks = overdue_tasks.select { |ts| ts[:task_definition].target_grade == i  }

      graded_tasks.each do |ts|
        result << { task_definition: ts[:task_definition], status: ts[:status], reason: :overdue }
      end

      return result.slice(0..4) if result.count >= 5
    end

    #
    # Add in soon tasks...
    #
    soon_tasks = task_states.select { |ts| to_target.call(ts) >= Time.zone.today && to_target.call(ts) < Time.zone.today + 7.days }

    for i in 0..3
      graded_tasks = soon_tasks.select { |ts| ts[:task_definition].target_grade == i  }

      graded_tasks.each do |ts|
        result << { task_definition: ts[:task_definition], status: ts[:status], reason: :soon }
      end

      return result.slice(0..4) if result.count >= 5
    end

    #
    # Add in ahead tasks...
    #
    ahead_tasks = task_states.select { |ts| to_target.call(ts) >= Time.zone.today + 7.days }

    for i in 0..3
      graded_tasks = ahead_tasks.select { |ts| ts[:task_definition].target_grade == i  }

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

  #
  # Calculate and return the burndown chart data
  # returns four lines:
  # - projected based on previous work marked as at least "ready to assessess"
  # - target based on task definitions
  # - done based on work marked as at least "ready to assess"
  # - complete based on work signed off as complete
  def burndown_chart_data
    # Create buckets by week
    result = [ ]

    # Get the weeks between start and end date as an array
    # dates = unit.start_date.to_date.step(unit.end_date.to_date + 1.week, step=7).to_a
    dates = unit.start_date.to_date.step(unit.end_date.to_date + 3.week, 7).to_a

    # Setup the dictionaries to contain the keys and values
    # key = series name
    # values = array of [ x, y ] values
    projected_results = { key: 'Projected', values: [] }
    target_task_results = { key: 'Target', values: [] }
    done_task_results = { key: 'To Submit', values: [] }
    complete_task_results = { key: 'To Complete', values: [] }

    result.push(target_task_results)
    result.push(projected_results)
    result.push(done_task_results)
    result.push(complete_task_results)

    # Get the target task from the unit's task definitions
    target_tasks = assigned_task_defs

    return if target_tasks.count == 0

    # get total value of all tasks assigned to this project
    total = target_tasks.map { |td| td.weighting.to_f }.inject(:+)

    # last done task date
    if ready_or_complete_tasks.empty?
      last_target_date = unit.start_date
    else
      last_target_date = ready_or_complete_tasks.sort { |a, b| a.due_date <=> b.due_date }.last.due_date
    end

    # today is used to determine when to stop adding done tasks
    today = reference_date

    # Actual tasks
    my_tasks = tasks

    # Get the tasks currently marked as done (or ready to mark)
    done_tasks = tasks_in_submitted_status

    # use weekly completion rate to determine projected progress
    completion_rate = weekly_completion_rate
    projected_remaining = total

    # Track which values to add
    add_target = true
    add_projected = true
    add_done = true

    # Iterate over the dates
    dates.each do |date|
      # get the target values - those from the task definitions
      target_val = [ date.to_datetime.to_i,
                     target_tasks.select { |task_def| (tasks.where(task_definition: task_def).empty? ? task_def.target_date : tasks.where(task_definition: task_def).first.due_date ) > date }.map { |task_def| task_def.weighting.to_f }.inject(:+)]
      # get the done values - those done up to today, or the end of the unit
      done_val = [ date.to_datetime.to_i,
                   done_tasks.select { |task| task.submission_date.present? && task.submission_date <= date }.map { |task| task.task_definition.weighting.to_f }.inject(:+)]
      # get the completed values - those signed off
      complete_val = [ date.to_datetime.to_i,
                       completed_tasks.select { |task| task.completion_date <= date }.map { |task| task.task_definition.weighting.to_f }.inject(:+)]
      # projected value is based on amount done
      projected_val = [ date.to_datetime.to_i, projected_remaining / total ]

      # add one week's worth of completion data
      projected_remaining -= completion_rate

      # if target value then its the %remaining only
      target_val[1].nil? ? (target_val[1] = 0) : (target_val[1] /= total)
      # if no done value then value is 100%, otherwise remaining is the total - %done
      done_val[1] = (done_val[1].nil? ? 1 : (total - done_val[1]) / total)
      complete_val[1].nil? ? (complete_val[1] = 1) : (complete_val[1] = (total - complete_val[1]) / total)

      # add target, done and projected if appropriate
      target_task_results[:values].push target_val if add_target
      if add_done
        done_task_results[:values].push done_val
        complete_task_results[:values].push complete_val
      end
      projected_results[:values].push projected_val if add_projected

      # stop adding the target values once zero target value is reached
      add_target = false if add_target && target_val[1] == 0
      # stop adding the done tasks once past date - (add once for tasks done this week, hence after adding)
      add_done = false if add_done && date > today
      # stop adding projected values once projected is complete
      add_projected = false if add_projected && projected_val[1] <= 0
    end

    result
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
    hash.each { |_key, value| total += value }

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

  # Calculate the task stats text to send progress data back to the client
  # Total task counts must contain an array of the cummulative task counts (with none being 0)
  # Project task counts is an object with fail_count, complete_count etc for each status
  def self.create_task_stats_from(total_task_counts, project_task_counts, target_grade)
    red_pct = ((project_task_counts.fail_count + project_task_counts.do_not_resubmit_count + project_task_counts.time_exceeded_count) / total_task_counts[target_grade]).signif(2)
    orange_pct = ((project_task_counts.redo_count + project_task_counts.need_help_count + project_task_counts.fix_and_resubmit_count) / total_task_counts[target_grade]).signif(2)
    green_pct = ((project_task_counts.discuss_count + project_task_counts.demonstrate_count + project_task_counts.complete_count) / total_task_counts[target_grade]).signif(2)
    blue_pct = (project_task_counts.ready_to_mark_count / total_task_counts[target_grade]).signif(2)
    grey_pct = (1 - red_pct - orange_pct - green_pct - blue_pct).signif(2)

    order_scale = green_pct * 100 + blue_pct * 100 + orange_pct * 10 - red_pct

    {
      red_pct: red_pct,
      grey_pct: grey_pct,
      orange_pct: orange_pct,
      blue_pct: blue_pct,
      green_pct: green_pct,
      order_scale: order_scale
    }
  end

  def task_stats
    task_count = [0, 1, 2, 3].map do |e|
      unit.task_definitions.where("target_grade <= #{e}").count + 0.0
    end.map { |e| e == 0 ? 1 : e }

    result = assigned_tasks
        .group('project_id')
        .select(
          'project_id',
          *TaskStatus.all.map { |s| "SUM(CASE WHEN tasks.task_status_id = #{s.id} THEN 1 ELSE 0 END) AS #{s.status_key}_count" }
        )
        .map do |t| Project.create_task_stats_from(task_count, t, target_grade) end
        .first

    if result.nil?
      {
        red_pct: 0,
        grey_pct: 1,
        orange_pct: 0,
        blue_pct: 0,
        green_pct: 0,
        order_scale: 0
      }
    else
      result
    end
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

  #
  # Portfolio production code
  #
  def portfolio_temp_path
    portfolio_dir = FileHelper.student_portfolio_dir(self.unit, self.student.username, false)
    portfolio_tmp_dir = File.join(portfolio_dir, 'tmp')
  end

  def portfolio_tmp_file_name(dict)
    extn = File.extname(dict[:name])
    name = File.basename(dict[:name], extn)
    name = name.tr('.', '_') + extn
    FileHelper.sanitized_filename("#{dict[:idx].to_s.rjust(3, '0')}-#{dict[:kind]}-#{name}")
  end

  def portfolio_tmp_file_path(dict)
    File.join(portfolio_temp_path, portfolio_tmp_file_name(dict))
  end

  def move_to_portfolio(file, name, kind)
    # get path to portfolio dir
    # get path to tmp folder where file parts will be stored
    portfolio_tmp_dir = portfolio_temp_path
    FileUtils.mkdir_p(portfolio_tmp_dir)
    result = {
      kind: kind,
      name: file.filename
    }

    # copy up the learning summary report as first -- otherwise use files to determine idx
    if name == 'LearningSummaryReport' && kind == 'document'
      result[:idx] = 0
      result[:name] = 'LearningSummaryReport.pdf'
    else
      Dir.chdir(portfolio_tmp_dir)
      files = Dir.glob('*')
      idx = files.map { |a_file| a_file.split('-').first.to_i }.max
      if idx.nil? || idx < 1
        idx = 1
      else
        idx += 1
      end
      result[:idx] = idx
    end

    dest_file = portfolio_tmp_file_name(result)
    FileUtils.cp file.tempfile.path, File.join(portfolio_tmp_dir, dest_file)
    result
  end

  def portfolio_files(ensure_valid = false, force_ascii = false)
    # get path to portfolio dir
    portfolio_tmp_dir = portfolio_temp_path
    return [] unless Dir.exist? portfolio_tmp_dir

    result = []

    Dir.chdir(portfolio_tmp_dir)
    files = Dir.glob('*').select { |f| (f =~ /^\d{3}\-(cover|document|code|image)/) == 0 }
    files.each do |file|
      parts = file.split('-')
      idx = parts[0].to_i
      kind = parts[1]
      name = parts.drop(2).join('-')
      result << { kind: kind, name: name, idx: idx }

      FileHelper.ensure_utf8_code(file, force_ascii) if ensure_valid && kind == "code"
    end

    result
  end

  # Remove a file from the portfolio tmp folder
  def remove_portfolio_file(idx, kind, name)
    # get path to portfolio dir
    portfolio_tmp_dir = portfolio_temp_path
    return unless Dir.exist? portfolio_tmp_dir

    # the file is in the students portfolio tmp dir
    rm_file = File.join(
      portfolio_tmp_dir,
      FileHelper.sanitized_filename("#{idx.to_s.rjust(3, '0')}-#{kind}-#{name}")
    )

    # try to remove the file
    begin
      FileUtils.rm rm_file if File.exist? rm_file
    rescue
    end
  end

  def portfolio_path
    FileHelper.student_portfolio_path(self.unit, self.student.username, true)
  end

  def has_portfolio
    (!portfolio_production_date.nil?) && portfolio_available
  end

  def portfolio_status
    if has_portfolio
      'YES'
    elsif compile_portfolio
      'in process'
    else
      'no'
    end
  end

  def portfolio_available
    (File.exist? portfolio_path) && !compile_portfolio
  end

  def remove_portfolio
    portfolio = portfolio_path
    FileUtils.mv portfolio, "#{portfolio}.old" if File.exist?(portfolio)
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

  class ProjectAppController < ApplicationController
    attr_accessor :student
    attr_accessor :project
    attr_accessor :base_path
    attr_accessor :image_path
    attr_accessor :learning_summary_report
    attr_accessor :ordered_tasks
    attr_accessor :portfolio_tasks
    attr_accessor :task_defs
    attr_accessor :outcomes

    def init(project, is_retry)
      @student = project.student
      @project = project
      @learning_summary_report = project.learning_summary_report_path
      @files = project.portfolio_files(true, is_retry)
      @base_path = project.portfolio_temp_path
      @image_path = Rails.root.join('public', 'assets', 'images')
      @ordered_tasks = project.tasks.joins(:task_definition).order('task_definitions.start_date, task_definitions.abbreviation').where("task_definitions.target_grade <= #{project.target_grade}")
      @portfolio_tasks = project.portfolio_tasks
      @task_defs = project.unit.task_definitions.order(:start_date)
      @outcomes = project.unit.learning_outcomes.order(:ilo_number)
      @institution_name = Doubtfire::Application.config.institution[:name]
      @doubtfire_product_name = Doubtfire::Application.config.institution[:product_name]
    end

    def make_pdf
      render_to_string(template: '/portfolio/portfolio_pdf.pdf.erb', layout: true)
    end
  end

  #
  # Return the path to the student's learning summary report.
  # This returns nil if there is no learning summary report.
  #
  def learning_summary_report_path
    portfolio_tmp_dir = portfolio_temp_path

    return nil unless Dir.exist? portfolio_tmp_dir

    filename = "#{portfolio_tmp_dir}/000-document-LearningSummaryReport.pdf"
    return nil unless File.exist? filename
    filename
  end

  def create_portfolio
    return false unless compile_portfolio

    self.compile_portfolio = false
    save!

    begin
      pac = ProjectAppController.new
      pac.init(self, false)

      begin
        pdf_text = pac.make_pdf
      rescue => e
        # Try again... with convert to ascii
        pac2 = ProjectAppController.new
        pac2.init(self, true)

        pdf_text = pac2.make_pdf
      end

      File.open(portfolio_path, 'w') do |fout|
        fout.puts pdf_text
      end

      logger.info "Created portfolio at #{portfolio_path} - #{log_details}"

      self.portfolio_production_date = Time.zone.now
      save
      return true
    rescue => e
      logger.error "Failed to convert portfolio to PDF - #{log_details} -\nError: #{e.message}"

      log_file = e.message.scan(/\/.*\.log/).first
      if log_file && File.exist?(log_file)
        begin
          puts "--- Latex Log ---\n"
          puts File.read(log_file)
          puts "---    End    ---\n\n"
        rescue
        end
      end
      return false
    end
  end

  def send_weekly_status_email ( summary_stats, middle_of_unit )
    did_revert_to_pass = false
    if middle_of_unit && should_revert_to_pass && ! has_portfolio
      self.target_grade = 0
      save
      did_revert_to_pass = true

      summary_stats[:revert_count] = summary_stats[:revert_count] + 1
      summary_stats[:revert][main_convenor_user] << self
    end

    return unless student.receive_feedback_notifications
    return if has_portfolio && ! middle_of_unit
    NotificationsMailer.weekly_student_summary(self, summary_stats, did_revert_to_pass).deliver_now
  end

  private
  def can_destroy?
    return true if tutorial_enrolments.count == 0
    errors.add :base, "Cannot delete project with enrolments"
    false
  end
end
