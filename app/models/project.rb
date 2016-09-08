class Float
  def signif(signs)
    Float("%.#{signs}f" % self)
  end
end

class Project < ActiveRecord::Base
  include ApplicationHelper
  include LogHelper

  belongs_to :unit
  belongs_to :tutorial
  belongs_to :user

  # has_one :user, through: :student
  has_many :tasks, dependent: :destroy   # Destroying a project will also nuke all of its tasks

  has_many :group_memberships, dependent: :destroy
  has_many :groups, -> { where("group_memberships.active = :value", value: true) },  through: :group_memberships
  has_many :past_groups, -> { where("group_memberships.active = :value", value: false) },  through: :group_memberships, source: 'group'

  has_many :learning_outcome_task_links, through: :tasks

  validate :must_be_in_group_tutorials
  validates_length_of :grade_rationale, :maximum => 4095, :allow_blank => true

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
      :assess
    ]
    # What can convenors do with projects?
    convenor_role_permissions = [

    ]
    # What can nil users do with projects?
    nil_role_permissions = [

    ]

    # Return permissions hash
    {
      :student => student_role_permissions,
      :tutor   => tutor_role_permissions,
      :nil     => nil_role_permissions
    }
  end

  def role_for(user)
    return user_role(user)
  end

  scope :with_progress, lambda {|progress_types|
    where(progress: progress_types) unless progress_types.blank?
  }

  def self.for_user(user, include_inactive)
    if include_inactive
      where('projects.user_id = :user_id', user_id: user.id)
    else
      active_projects.where('projects.user_id = :user_id', user_id: user.id)
    end
  end

  def self.active_projects
    joins(:unit).where(enrolled: true).where('units.active = TRUE')
  end

  def self.for_unit_role(unit_role)
    if unit_role.is_teacher?
      active_projects.where(unit_id: unit_role.unit_id)
    else
      nil
    end
  end

  #
  # Check to see if the student has a valid tutorial
  #
  def must_be_in_group_tutorials
    groups.each { |g|
      if g.limit_members_to_tutorial?
        if tutorial != g.tutorial
          if g.group_set.allow_students_to_manage_groups
            # leave group
            g.remove_member(self)
          else
            errors.add(:groups, "require you to be in tutorial #{g.tutorial.abbreviation}")
            break
          end
        end
      end
    }
  end

  def log_details
    "#{id} - #{student.name} (#{student.username}) #{unit.code}"
  end

  def task_outcome_alignments
    learning_outcome_task_links
  end

  #
  # Returns the email of the tutor, or the convenor if there is no tutor
  #
  def tutor_email
    tutor = main_tutor
    if tutor
      tutor.email
    else
      unit.convenor_email
    end
  end

  #
  # All "discuss" and "demonstrate" become complete
  #
  def trigger_week_end( by_user )
    discuss_and_demonstrate_tasks.each{|task| task.trigger_transition(trigger: "complete", by_user: by_user, bulk: true, quality: task.quality_pts) }
    #TODO: Remove once task_stats deleted
    #calc_task_stats
  end

  def start
    update_attribute(:started, true)
  end

  def student
    user
  end

  def main_tutor
    if tutorial
      result = tutorial.tutor
      result = main_convenor if result.nil?
      result
    else
      main_convenor
    end
  end

  def main_convenor
    unit.convenors.first.user
  end

  def tutorial_abbr
    tutorial.abbreviation unless tutorial.nil?
  end

  def user_role(user)
    if user == student then :student
    elsif user == main_tutor then :tutor
    elsif user.nil? then nil
    elsif self.unit.tutors.where(id: user.id).count != 0 then :tutor
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

  def assigned_tasks
    tasks.joins(:task_definition).where("task_definitions.target_grade <= :target", target: target_grade )
  end

  def portfolio_tasks
    # Get assigned tasks that are included in the portfolio
    tasks = self.tasks.joins(:task_definition).order("task_definitions.target_date, task_definitions.abbreviation").where("tasks.include_in_portfolio = TRUE")

    # Remove the tasks that are not aligned... if there are ILOs
    if unit.learning_outcomes.length > 0
      tasks = tasks.select { |t| t.learning_outcome_task_links.count > 0 }
    end

    # Now select the tasks that and have a PDF... cant include the others...
    portfolio_tasks = tasks.select{ |task| task.has_pdf }
  end

  def progress
    self[:progress].to_sym
  end

  def progress=(value)
    self[:progress] = value.to_s
  end

  def status
    self[:status].to_sym
  end

  def status=(value)
    self[:status] = value.to_s
  end

  def target_grade=(value)
    self[:target_grade] = value
    #TODO: Remove once task_stats deleted
    # calc_task_stats
  end

  def calculate_progress
    relative_progress      = progress_in_weeks

    if relative_progress >= 0
      :ahead
    elsif relative_progress == -1 or relative_progress == -2
      :on_track
    else
      weeks_behind = relative_progress.abs

      if weeks_behind <= 3
        :behind
      elsif weeks_behind > 3 && weeks_behind <= 5
        :danger
      else
        :doomed
      end
    end
  end

  def calculate_status
    if !commenced?
      :not_commenced
    elsif concluded?
      completed? ? :completed : :not_completed
    else
      if completed?
        :completed
      elsif started?
        :in_progress
      else
        :not_started
      end
    end
  end

  def progress_in_weeks
    progress_in_days / 7
  end

  def progress_in_days
    units_completed = task_units_completed

    # current_week  = weeks_elapsed
    date_progress = unit.start_date

    progress_points.each do |date, weight|
      break if weight > units_completed
      date_progress = date
    end

    (date_progress - reference_date).to_i / 1.day
  end

  def progress_points
    date_accumulated_weight_map = {}

    assigned_tasks.sort{|a, b| a.task_definition.target_date <=>  b.task_definition.target_date}.each do |project_task|
      date_accumulated_weight_map[project_task.task_definition.target_date] = assigned_tasks.select{|task|
        task.task_definition.target_date <= project_task.task_definition.target_date
      }.map{|task| task.task_definition.weighting.to_f}.inject(:+)
    end

    date_accumulated_weight_map
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
    dates = unit.start_date.to_date.step(unit.end_date.to_date + 1.week, 7).to_a

    # Setup the dictionaries to contain the keys and values
    # key = series name
    # values = array of [ x, y ] values
    projected_results = { key: "Projected", values: [] }
    target_task_results = { key: "Target", values: [] }
    done_task_results = { key: "To Submit", values: [] }
    complete_task_results = { key: "To Complete", values: [] }

    result.push(target_task_results)
    result.push(projected_results)
    result.push(done_task_results)
    result.push(complete_task_results)

    # Get the target task from the unit's task definitions
    target_tasks = assigned_task_defs

    return if target_tasks.count == 0

    # get total value of all tasks assigned to this project
    total = target_tasks.map{|td| td.weighting.to_f}.inject(:+)

    #last done task date
    if ready_or_complete_tasks.empty?
      last_target_date = unit.start_date
    else
      last_target_date = ready_or_complete_tasks.sort{|a,b| a.task_definition.target_date <=>  b.task_definition.target_date }.last.task_definition.target_date
    end

    # today is used to determine when to stop adding done tasks
    today = reference_date

    # Get the tasks currently marked as done (or ready to mark)
    done_tasks = ready_or_complete_tasks

    # use weekly completion rate to determine projected progress
    completion_rate = weekly_completion_rate
    projected_remaining = total

    # Track which values to add
    add_target = true
    add_projected = true
    add_done = true

    # Iterate over the dates
    dates.each { |date|
      # get the target values - those from the task definitions
      target_val = [ date.to_datetime.to_i,
          target_tasks.select{|task_def| task_def.target_date > date}.map{|task_def| task_def.weighting.to_f}.inject(:+)
        ]
      # get the done values - those done up to today, or the end of the unit
      done_val = [ date.to_datetime.to_i,
          done_tasks.select{|task| (not task.completion_date.nil?) && task.completion_date <= date}.map{|task| task.task_definition.weighting.to_f}.inject(:+)
        ]
      # get the completed values - those signed off
      complete_val = [ date.to_datetime.to_i,
          completed_tasks.select{|task| task.completion_date <= date}.map{|task| task.task_definition.weighting.to_f}.inject(:+)
        ]
      # projected value is based on amount done
      projected_val = [ date.to_datetime.to_i, projected_remaining / total ]

      # add one week's worth of completion data
      projected_remaining -= completion_rate

      # if target value then its the %remaining only
      if target_val[1].nil?     then  target_val[1] = 0     else target_val[1] /= total end
      # if no done value then value is 100%, otherwise remaining is the total - %done
      if done_val[1].nil?       then  done_val[1] = 1       else done_val[1] = (total - done_val[1]) / total end
      if complete_val[1].nil?   then  complete_val[1] = 1   else complete_val[1] = (total - complete_val[1]) / total end

      # add target, done and projected if appropriate
      if add_target then target_task_results[:values].push target_val end
      if add_done
        done_task_results[:values].push done_val
        complete_task_results[:values].push complete_val
      end
      if add_projected then projected_results[:values].push projected_val end

      # stop adding the target values once zero target value is reached
      if add_target && target_val[1] == 0 then add_target = false end
      # stop adding the done tasks once past date - (add once for tasks done this week, hence after adding)
      if add_done && date > today then add_done = false end
      # stop adding projected values once projected is complete
      if add_projected && projected_val[1] <= 0 then add_projected = false end
    }

    result
  end

  def projected_end_date
    return unit.end_date if rate_of_completion == 0.0
    (remaining_tasks_weight / rate_of_completion).ceil.days.since reference_date
  end

  def weeks_elapsed(date=nil)
    (days_elapsed(date) / 7.0).ceil
  end

  def days_elapsed(date=nil)
    date ||= reference_date
    (date - unit.start_date).to_i / 1.day
  end

  def rate_of_completion(date=nil)
    # Return a completion rate of 0.0 if the project is yet to have commenced
    return 0.0 if !commenced? || completed_tasks.empty?
    date ||= reference_date

    # TODO: Might make sense to take in the resolution (i.e. days, weeks), rather
    # than just assuming days

    # If on the first day (i.e. a day has not yet passed, but the project
    # has commenced), force days elapsed to be 1 to avoid divide by zero
    days = days_elapsed(date)
    days = 1 if days_elapsed(date) < 1

    completed_tasks_weight / days.to_f
  end

  def weekly_completion_rate(date=nil)
    # Return a completion rate of 0.0 if the project is yet to have commenced
    return 0.0 if ready_or_complete_tasks.empty?
    date ||= reference_date

    weeks = weeks_elapsed(date)
    # Ensure at least one week
    weeks = 1 if weeks < 1

    completed_tasks_weight / weeks.to_f
  end

  def required_task_completion_rate
    remaining_tasks_weight / remaining_days
  end

  def recommended_completed_tasks
    assigned_tasks.select{|task| task.task_definition.target_date < reference_date }
  end

  def completed_tasks
    assigned_tasks.select{|task| task.complete? }
  end

  def ready_to_mark_tasks
    assigned_tasks.select{|task| task.ready_to_mark? }
  end

  def ready_or_complete_tasks
    assigned_tasks.select{|task| task.ready_or_complete? }
  end

  def discuss_and_demonstrate_tasks
    tasks.select{|task| task.discuss_or_demonstrate? }
  end

  def partially_completed_tasks
    # TODO: Should probably have a better definition
    # of partially complete than just 'fix' tasks
    assigned_tasks.select{|task| task.fix_and_resubmit? || task.do_not_resubmit? }
  end

  def completed?
    # TODO: Have a status flag on the project instead
    assigned_tasks.all?{|task| task.complete? }
  end

  def incomplete_tasks
    assigned_tasks.select{|task| !task.complete? }
  end

  def percentage_complete
    completed_tasks.empty? ? 0.0 : (completed_tasks_weight / total_task_weight) * 100
  end

  def remaining_tasks_weight
    incomplete_tasks.empty? ? 0.0 : incomplete_tasks.map{|task| task.task_definition.weighting }.inject(:+)
  end

  #
  # get the weight of all tasks completed or marked as ready to assess
  #
  def completed_tasks_weight
    ready_or_complete_tasks.empty? ? 0.0 : ready_or_complete_tasks.map{|task| task.task_definition.weighting }.inject(:+)
  end

  def partially_completed_tasks_weight
    # Award half for partially completed tasks
    # TODO: Should probably make this a project-by-project option
    partially_complete = partially_completed_tasks
    partially_complete.empty? ? 0.0 : partially_complete.map{|task| task.task_definition.weighting / 2.to_f }.inject(:+)
  end

  def task_units_completed
    completed_tasks_weight + partially_completed_tasks_weight
  end

  def convert_hash_to_pct(hash, total)
    hash.each { |key, value| if hash[key] < 0.01 then hash[key] = 0.0 else hash[key] = (value / total).signif(2) end }

    total = 0.0
    hash.each { |key, value| total += value }

    if total != 1.0
      dif = 1.0 - total
      hash.each { |key, value|
        if value > 0.0
          hash[key] = (hash[key] + dif).signif(2)
          break
        end
      }
    end
  end

  def task_stats
    task_count = unit.task_definitions.where("target_grade <= #{target_grade}").count + 0.0
    task_count = 1.0 unless task_count > 1.0
    tasks.
      group("project_id").
      select(
        "project_id",
        *TaskStatus.all.map { |s| "SUM(CASE WHEN tasks.task_status_id = #{s.id} THEN 1 ELSE 0 END) AS #{s.status_key}_count" }
        ).
      map { |t|
        # puts "#{t.project_id} #{t.first_name} #{t.fail_count} Grade:#{t.grade} Count:#{task_count[t.grade]}"
        fail_pct = (t.fail_count / task_count).signif(2)
        do_not_resubmit_pct = (t.do_not_resubmit_count / task_count).signif(2)
        redo_pct = (t.redo_count / task_count).signif(2)
        need_help_pct = (t.need_help_count / task_count).signif(2)
        working_on_it_pct = (t.working_on_it_count / task_count).signif(2)
        fix_and_resubmit_pct = (t.fix_and_resubmit_count / task_count).signif(2)
        ready_to_mark_pct = (t.ready_to_mark_count / task_count).signif(2)
        discuss_pct = (t.discuss_count / task_count).signif(2)
        demonstrate_pct = (t.demonstrate_count / task_count).signif(2)
        complete_pct = (t.complete_count / task_count).signif(2)

        not_started_pct = (1 - fail_pct - do_not_resubmit_pct - redo_pct - need_help_pct - working_on_it_pct - fix_and_resubmit_pct - ready_to_mark_pct - discuss_pct - demonstrate_pct - complete_pct).signif(2)

        "#{fail_pct}|#{not_started_pct}|#{do_not_resubmit_pct}|#{redo_pct}|#{need_help_pct}|#{working_on_it_pct}|#{fix_and_resubmit_pct}|#{ready_to_mark_pct}|#{discuss_pct}|#{demonstrate_pct}|#{complete_pct}"
      }.first
  end

  def calc_task_stats ( reload_task = nil )
    self.task_stats
  end

  def assigned_task_defs
    unit.task_definitions.where("target_grade <= :grade", grade: target_grade)
  end

  def total_task_weight
    assigned_task_defs.map{|td| td.weighting }.inject(:+)
  end

  #
  # Tasks currently due - but not complete
  #
  def currently_due_tasks
    assigned_tasks.select{|task| task.currently_due? }
  end

  #
  # All tasks currently due
  #
  def due_tasks
    assigned_tasks.select { |task| task.target_date < reference_date }
  end

  def overdue_tasks
    assigned_tasks.select{|task| task.overdue? }
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
    completed_tasks.sort{|a, b| a.completion_date <=> b.completion_date }.last
  end

  def task_completion_csv()
    all_tasks = unit.task_definitions_by_grade
    [
      student.username,
      student.name,
      target_grade_desc,
      student.email,
      portfolio_status,
      if tutorial then tutorial.abbreviation else '' end,
      main_tutor().name
    ] +
    unit.group_sets.map { |gs|
      grp = group_for_groupset(gs)
      if grp then grp.name else nil end
    } +
    all_tasks.map { |td|
      task = tasks.where(task_definition_id: td.id).first
      if task
        status = task.task_status.name
        grade = task.grade_desc
        stars = task.quality_pts
        people = task.contribution_pts
      else
        status = TaskStatus.not_started.name
        grade = nil
        stars = nil
        people = nil
      end

      result = [status]
      result << grade if td.is_graded?
      result << stars if td.has_stars?
      result << people if td.is_group_task?
      result
    }.flatten
  end

  #
  # Portfolio production code
  #
  def portfolio_temp_path
    portfolio_dir = FileHelper.student_portfolio_dir(self, false)
    portfolio_tmp_dir = File.join(portfolio_dir, "tmp")
  end

  def portfolio_tmp_file_name(dict)
    extn = File.extname(dict[:name])
    name = File.basename(dict[:name], extn)
    name = name.gsub(".","_") + extn
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
    if name == "LearningSummaryReport" && kind == "document"
      result[:idx] = 0
      result[:name] = "LearningSummaryReport.pdf"
    else
      Dir.chdir(portfolio_tmp_dir)
      files = Dir.glob("*")
      idx = files.map { |a_file| a_file.split("-").first.to_i }.max
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

  def portfolio_files()
    # get path to portfolio dir
    portfolio_tmp_dir = portfolio_temp_path
    return [] unless Dir.exists? portfolio_tmp_dir

    result = []

    Dir.chdir(portfolio_tmp_dir)
    files = Dir.glob("*").select { | f | (f =~ /^\d{3}\-(cover|document|code|image)/) == 0 }
    files.each { | file |
      parts = file.split("-");
      idx = parts[0].to_i
      kind = parts[1]
      name = parts.drop(2).join("-")
      result << { kind: kind, name: name, idx: idx }
    }

    result
  end

  # Remove a file from the portfolio tmp folder
  def remove_portfolio_file(idx, kind, name)
    # get path to portfolio dir
    portfolio_tmp_dir = portfolio_temp_path
    return unless Dir.exists? portfolio_tmp_dir

    # the file is in the students portfolio tmp dir
    rm_file = File.join(
        portfolio_tmp_dir,
        FileHelper.sanitized_filename("#{idx.to_s.rjust(3, '0')}-#{kind}-#{name}")
      )

    # try to remove the file
    begin
      if File.exists? rm_file
        FileUtils.rm rm_file
      end
    rescue
    end
  end

  #
  # Make file coverpage
  #
  def create_task_cover_page(dest_dir)

    #
    # check later -- not working at the moment fa not rendering in pdfkit
    # @acain: this won't work as we haven't imported font-awesome on the server
    #
    # status_icons = {
    #   ready_to_mark: 'fa fa-thumbs-o-up',
    #   not_started: 'fa fa-times',
    #   working_on_it: 'fa fa-bolt',
    #   need_help: 'fa fa-question-circle',
    #   redo: 'fa fa-refresh',
    #   do_not_resubmit: 'fa fa-stop',
    #   fix_and_resubmit: 'fa fa-wrench',
    #   discuss: 'fa fa-check',
    #   complete: 'fa fa-check-circle-o'
    # }

    grade_descs = [
      'Pass',
      'Credit',
      'Distinction',
      'High Distinction'
    ]

    ordered_tasks = tasks.joins(:task_definition).order("task_definitions.target_date, task_definitions.abbreviation").select{|task| task.task_definition.target_grade <= target_grade }
    coverpage_html = <<EOF
<html>
  <head>
    <link rel='stylesheet' type='text/css' href='https://doubtfire.ict.swin.edu.au/assets/doubtfire.css'>
  </head>
  <body>
    <h2>
      #{unit.name} <small>#{unit.code}</small>
      <p class="lead">#{student.name} <small>#{student.username}</small></p>
    </h2>
    <h1>Tasks for #{student.name}</h1>
    <table class='table table-striped'>
      <thead>
        <th>Task</th>
        <th colspan='2'>Status</th>
        <th>Included</th>
        <th>Grade</th>
      </thead>
      <tbody>
EOF

    ordered_tasks.each do | task |
      task_row_html = <<EOF
<tr>
  <td>#{task.task_definition.name}</td>
  <td>#{task.task_status.name}</td>
  <td><button type='button' class='col-xs-12 btn btn-default task-status #{task.status.to_s.dasherize}'>#{task.task_definition.abbreviation}</button></td>
  <td><i class="glyphicon glyphicon-#{ (task.include_in_portfolio && task.has_pdf ? 'checked' : 'unchecked')}"></i></td>
  <td>#{task.grade.nil? ? 'N/A' : grade_descs[task.grade]}</td>
</tr>
EOF
      coverpage_html << task_row_html
    end

    coverpage_html << "</tbody></table></body></html>"

    cover_filename = File.join(dest_dir, "task.cover.html")

    logger.debug("Generating cover page #{cover_filename} - #{log_details()}")

    #
    # Create cover page for the submitted file (<taskid>/file0.cover.html etc.)
    #
    logger.debug "Generating cover page #{cover_filename} - #{log_details()}"

    coverp_file = File.new(cover_filename, "w")
    coverp_file.write(coverpage_html)
    coverp_file.close

    cover_filename
  end

  def portfolio_path()
    File.join(FileHelper.student_portfolio_dir(self, true), FileHelper.sanitized_filename("#{student.username}-portfolio.pdf"))
  end

  def has_portfolio()
    not self.portfolio_production_date.nil?
  end

  def portfolio_status()
    if self.has_portfolio
      'YES'
    elsif self.compile_portfolio
      'in process'
    else
      'no'
    end
  end

  def portfolio_available()
    (File.exists? portfolio_path) && ! self.compile_portfolio
  end

  def remove_portfolio()
    portfolio = portfolio_path()
    if File.exists?(portfolio)
      FileUtils.mv portfolio, "#{portfolio}.old"
    end
  end

  def recalculate_max_similar_pct
    # self.max_pct_similar = tasks.sort { |t1, t2|  t1.max_pct_similar <=> t2.max_pct_similar }.last.max_pct_similar
    # self.save
  end

  def matching_task(other_task)
    task_for_task_definition(other_task.task_definition)
  end

  def has_task_for_task_definition?(td)
    ! tasks.where(task_definition: td).first.nil?
  end

  #
  # Get the task for the requested definition. This will create the
  # task if the task does not exist for this project.
  #
  def task_for_task_definition(td)
    logger.debug "Finding task #{td.abbreviation} for project #{log_details()}"
    result = tasks.where(task_definition: td).first
    if result.nil?
      begin
        result = Task.create!(
          task_definition_id: td.id,
          project_id: id,
          task_status_id: 1
        )
        logger.info "Created task #{result.id} - #{td.abbreviation} for project #{log_details()}"
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
    group_memberships.joins(:group).where("groups.group_set_id = :id", id: gs).first
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

    def init(project)
      @student = project.student
      @project = project
      @learning_summary_report = project.learning_summary_report_path
      @files = project.portfolio_files
      @base_path = project.portfolio_temp_path
      @image_path = Rails.root.join("public", "assets", "images")

      @ordered_tasks = project.tasks.joins(:task_definition).order("task_definitions.start_date, task_definitions.abbreviation").where("task_definitions.target_grade <= #{project.target_grade}")

      @portfolio_tasks = project.portfolio_tasks
      @task_defs = project.unit.task_definitions.order(:start_date)
      @outcomes = project.unit.learning_outcomes.order(:ilo_number)
    end

    def make_pdf()
      render_to_string(:template => "/portfolio/portfolio_pdf.pdf.erb", :layout => true)
    end
  end


  #
  # Return the path to the student's learning summary report.
  # This returns nil if there is no learning summary report.
  #
  def learning_summary_report_path
    portfolio_tmp_dir = portfolio_temp_path

    return nil unless Dir.exists? portfolio_tmp_dir

    filename = "#{portfolio_tmp_dir}/000-document-LearningSummaryReport.pdf"
    return nil unless File.exists? filename
    filename
  end

  def create_portfolio
    return false unless compile_portfolio

    self.compile_portfolio = false
    save!

    begin
      pac = ProjectAppController.new
      pac.init(self)

      pdf_text = pac.make_pdf

      File.open(self.portfolio_path, 'w') do |fout|
        fout.puts pdf_text
      end

      # FileHelper.compress_pdf(self.portfolio_path)

      logger.info "Created portfolio at #{portfolio_path} - #{log_details()}"

      self.portfolio_production_date = DateTime.now
      self.save
      return true
    rescue => e
      logger.error "Failed to convert portfolio to PDF - #{log_details()} -\nError: #{e.message}"

      log_file = e.message.scan(/\/.*\.log/).first
      # puts "log file is ... #{log_file}"
      if log_file && File.exists?(log_file)
        # puts "exists"
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
end
