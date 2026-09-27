class UnitRole < ApplicationRecord
  # Model associations
  belongs_to :unit, optional: false    # Foreign key
  belongs_to :user, optional: false    # Foreign key

  belongs_to :role, optional: false    # Foreign key

  belongs_to :mentor, class_name: 'UnitRole', optional: true

  has_many :tutorials, class_name: 'Tutorial', dependent: :nullify
  has_many :projects, through: :tutorials
  has_many :tasks, through: :projects
  has_many :task_engagements, through: :tasks
  has_many :comments, through: :tasks

  has_many :tutor_notes, dependent: :destroy

  validates :unit_id, presence: true
  validates :user_id, presence: true
  validates :role_id, presence: true

  validate :ensure_valid_user_for_role
  validate :ensure_convenor, if: :is_main_convenor?
  validate :main_convenor_cant_be_observer

  before_destroy do
    if is_main_convenor?
      errors.add :base, 'Cannot delete this role as the user is the main contact for the unit'
      throw :abort
    end
  end

  scope :tutors,    -> { joins(:role).where('roles.name = :role', role: 'Tutor') }
  scope :convenors, -> { joins(:role).where('roles.name = :role', role: 'Convenor') }

  def tasks_awaiting_feedback
    tasks.joins(:task_definition).where('projects.enrolled = TRUE AND projects.target_grade >= task_definitions.target_grade AND tasks.task_status_id = :status', status: TaskStatus.ready_for_feedback)
  end

  def oldest_task_awaiting_feedback
    tasks_awaiting_feedback
      .includes(project: { unit: { teaching_period: :breaks } })
      .max_by(&:days_awaiting_feedback)
  end

  # Operational workload data for the tutor dashboard. This intentionally uses
  # the same task source as the tutor inbox so that dashboard figures follow the
  # inbox's assignment and visibility rules.
  def tutor_dashboard_stats(viewer:)
    now = Time.zone.now
    inbox_tasks = unit.tasks_for_task_inbox(user, true).to_a.uniq(&:task_id)
    ready_status_id = TaskStatus.ready_for_feedback.id
    need_help_status_id = TaskStatus.need_help.id
    ready_tasks = inbox_tasks.select { |task| task.status_id.to_i == ready_status_id }

    warning_cutoff = now - unit.feedback_warning_threshold_days.days
    overflow_cutoff = now - unit.feedback_overflow_threshold_days.days
    dated_ready_tasks = ready_tasks.select(&:submission_date)
    overdue_tasks = dated_ready_tasks.select { |task| task.submission_date <= overflow_cutoff }
    warning_tasks = dated_ready_tasks.select do |task|
      task.submission_date <= warning_cutoff && task.submission_date > overflow_cutoff
    end
    within_threshold_tasks = dated_ready_tasks.select { |task| task.submission_date > warning_cutoff }

    boolean_type = ActiveModel::Type::Boolean.new
    viewer_can_moderate_target = viewer.role == Role.convenor || mentor_id == viewer.id
    moderation_count =
      if viewer_can_moderate_target
        unit.tasks_for_moderation(viewer.user).count do |task|
          task_tutor = task.project.tutor_for(task.task_definition)
          task_tutor.present? && task_tutor.id == user_id
        end
      end

    {
      generated_at: now,
      unit_role: {
        id: id,
        role: role.name,
        user: {
          id: user.id,
          name: user.name,
          first_name: user.first_name,
          last_name: user.last_name,
          nickname: user.nickname
        }
      },
      thresholds: {
        warning_days: unit.feedback_warning_threshold_days,
        overflow_days: unit.feedback_overflow_threshold_days
      },
      inbox: {
        total_count: inbox_tasks.length,
        ready_for_feedback_count: ready_tasks.length,
        overdue_count: overdue_tasks.length,
        needs_help_count: inbox_tasks.count { |task| task.status_id.to_i == need_help_status_id },
        unread_activity_count: inbox_tasks.count { |task| task.number_unread.to_i.positive? },
        pinned_count: inbox_tasks.count { |task| boolean_type.cast(task.pinned) },
        age_buckets: {
          within_threshold_count: within_threshold_tasks.length,
          warning_count: warning_tasks.length,
          overdue_count: overdue_tasks.length,
          missing_submission_date_count: ready_tasks.count { |task| task.submission_date.blank? }
        },
        oldest_tasks: dashboard_oldest_tasks(ready_tasks, now),
        by_task_definition: dashboard_task_definition_breakdown(ready_tasks, overflow_cutoff)
      },
      tutor_notes: {
        total_count: tutor_notes.count,
        unread_by_tutor_count: tutor_notes
          .where(read_by_unit_role: false)
          .where.not(user_id: user_id)
          .count
      },
      moderation: {
        pending_count: moderation_count
      },
      permissions: {
        can_switch_tutor: viewer.role == Role.convenor,
        can_view_moderation: viewer.role == Role.convenor || unit.staff.where(mentor_id: viewer.id).exists?,
        can_view_overflow: viewer.can_mark_overflow_tasks?,
        can_access_tutor_notes: viewer == self || viewer.role == Role.convenor
      }
    }
  end

  def dashboard_oldest_tasks(ready_tasks, now)
    task_records = Task
                   .where(id: ready_tasks.map(&:task_id))
                   .includes(:task_definition, project: [:user, { unit: { teaching_period: :breaks } }])
                   .index_by(&:id)

    ready_tasks
      .filter_map { |task| task_records[task.task_id] }
      .select(&:submission_date)
      .sort_by(&:submission_date)
      .first(5)
      .map do |task|
        {
          id: task.id,
          project_id: task.project_id,
          student_id: task.project.student.id,
          student_name: task.project.student.name,
          task_definition_id: task.task_definition_id,
          task_definition_abbreviation: task.task_definition.abbreviation,
          task_definition_name: task.task_definition.name,
          submission_date: task.submission_date,
          days_awaiting_feedback: task.days_awaiting_feedback(now)
        }
      end
  end

  def dashboard_task_definition_breakdown(ready_tasks, overflow_cutoff)
    result = ready_tasks.group_by(&:task_definition_id).filter_map do |task_definition_id, tasks|
      task_definition = unit.task_definitions.find { |definition| definition.id == task_definition_id }
      next if task_definition.nil?

      {
        task_definition_id: task_definition.id,
        abbreviation: task_definition.abbreviation,
        name: task_definition.name,
        ready_for_feedback_count: tasks.length,
        overdue_count: tasks.count do |task|
          task.submission_date.present? && task.submission_date <= overflow_cutoff
        end
      }
    end

    result.sort_by { |row| [-row[:overdue_count], -row[:ready_for_feedback_count], row[:abbreviation]] }
  end

  private :dashboard_oldest_tasks, :dashboard_task_definition_breakdown

  #
  # Permissions around unit role data
  #
  def self.permissions
    # What can students do with unit roles?
    student_role_permissions = [
      :get
    ]
    # What can tutors do with unit roles?
    tutor_role_permissions = [
      :get,
      :create_tutor_note
    ]
    # What can convenors do with unit roles?
    convenor_role_permissions = [
      :get,
      :delete,
      :delete_tutor_note,
      :create_tutor_note
    ]
    # What can nil users do with unit roles?
    nil_role_permissions = []

    # Return permissions hash
    {
      student: student_role_permissions,
      tutor: tutor_role_permissions,
      convenor: convenor_role_permissions,
      nil: nil_role_permissions
    }
  end

  def self.tasks_to_review(user)
    Tutorial.find_by(user: user)
            .map(&:projects)
            .flatten
            .map(&:tasks)
            .flatten
            .select(&:reviewable?)
  end

  def role_for(user)
    unit_role = unit.role_for(user)
    unit_role = nil if unit_role == Role.student && self.user != user
    unit_role
  end

  def is_tutor?
    role == Role.tutor
  end

  def is_student?
    role == Role.student
  end

  def is_convenor?
    role == Role.convenor
  end

  def is_teacher?
    is_tutor? || is_convenor?
  end

  def has_students?
    number_of_students > 0
  end

  def number_of_students
    projects.where(enrolled: true).count
  end

  #
  # Add data to the summary stats about this staff member
  #
  def populate_summary_stats(summary_stats, tutorial_stream, tutorial, row)
    data = {}

    data[:staff] = user
    data[:unit_role] = self

    # All task engagements for this tutorial
    all_engagements = TaskEngagement
        .joins(task: [:project, :task_definition])
        .where(projects: { id: tutorial.projects.select(:id) })
        .where(task_definitions: { tutorial_stream_id: tutorial_stream.id })
        .distinct

    weekly_engagements = all_engagements
        .where("task_engagements.engagement_time >= :start AND task_engagements.engagement_time < :end",
               start: summary_stats[:week_start], end: summary_stats[:week_end])

    data[:engagements] = all_engagements
    data[:total_staff_engagements] = all_engagements.count
    data[:staff_engagements] = weekly_engagements.where(engagement: [TaskStatus.complete.name, TaskStatus.feedback_exceeded.name, TaskStatus.redo.name, TaskStatus.discuss.name, TaskStatus.rediscuss.name, TaskStatus.attention_required.name, TaskStatus.demonstrate.name, TaskStatus.fail.name])

    # Weekly task engagements for this tutorial
    data[:weekly_engagements_count] = weekly_engagements.count

    tutorial_tasks = tasks_awaiting_feedback
      .joins(task_definition: :tutorial_stream)
      .joins(project: { tutorial_enrolments: :tutorial })
      .where(tutorials: { id: tutorial.id })
      .where(task_definitions: { tutorial_stream_id: tutorial_stream.id })
      .distinct

    if tutorial_tasks.count > 0
      oldest_task = tutorial_tasks
        .includes(project: { unit: { teaching_period: :breaks } })
        .max_by(&:days_awaiting_feedback)

      data[:oldest_task_days] = oldest_task&.days_awaiting_feedback || 0
      data[:tasks_awaiting_feedback_count] = tutorial_tasks.count
    else
      data[:oldest_task_days] = 0
      data[:tasks_awaiting_feedback_count] = 0
    end

    data[:number_of_students] = tutorial.projects.count
    tutorial_task_ids = tutorial.projects.joins(:tasks).pluck('tasks.id')

    total_comments = comments
      .where(task_id: tutorial_task_ids)
      .where("task_comments.user_id = :staff_id",
             staff_id: data[:staff].id)
      .where(content_type: [:text, :assessment, :audio, :image, :pdf, :discussion, :extension, :discussed_in_class])
      .distinct

    data[:total_tasks_discussed] = total_comments
                .where(content_type: :discussed_in_class)

    data[:weekly_tasks_discussed] = data[:total_tasks_discussed]
                .where("task_comments.created_at > :start", start: Time.zone.now - 7.days)

    data[:received_comments] = total_comments
      .where("recipient_id = :staff_id AND task_comments.created_at > :start",
             staff_id: data[:staff].id,
             start: Time.zone.now - 7.days)

    data[:sent_comments] = total_comments
      .where("task_comments.user_id = :staff_id AND task_comments.created_at > :start",
             staff_id: data[:staff].id,
             start: Time.zone.now - 7.days)

    data[:total_comments] = total_comments

    summary_stats[:staff][data[:staff]][:staff_engagements] += data[:staff_engagements].count
    summary_stats[:staff][data[:staff]][:tasks_awaiting_feedback_count] += tutorial_tasks.count
    summary_stats[:staff][data[:staff]][:weekly_engagements_count] += weekly_engagements.count
    summary_stats[:staff][data[:staff]][:weekly_total_tasks_discussed] += data[:weekly_tasks_discussed].count
    summary_stats[:staff][data[:staff]][:oldest_task_days] = [
      summary_stats[:staff][data[:staff]][:oldest_task_days],
      data[:oldest_task_days]
    ].max

    row.replace(data)
  end

  def send_weekly_status_email(summary_stats)
    return unless user.receive_feedback_notifications

    begin
      NotificationsMailer.weekly_staff_summary(self, summary_stats).deliver_now
    rescue StandardError => e
      Rails.logger.error "Failed to send weekly staff summary email to #{user.email} - #{e.message}"
    end
  end

  def ensure_valid_user_for_role
    if is_convenor?
      errors.add :user, 'must have a role that is able to administer units (request admin to adjust user role)' unless user.has_convenor_capability?
    else
      errors.add :user, 'must have a role that is able to teach units (request admin to adjust user role)' unless user.has_tutor_capability?
    end
  end

  def main_convenor_cant_be_observer
    if unit.main_convenor_id == id && observer_only
      errors.add(:observer_only, 'cannot be set for the main convenor')
    end
  end

  def is_main_convenor?
    unit.main_convenor_id == id
  end

  def ensure_convenor
    errors.add(:user, 'must retain current role to administer units as they are currently the main contact for the unit') unless is_convenor?
  end

  def get_marking_sessions(start_date: nil, end_date: nil, timezone: nil)
    tz = Time.zone
    tz = ActiveSupport::TimeZone[timezone] if timezone

    end_date = if end_date.present?
                 tz.parse(end_date.to_s).end_of_day
               else
                 tz.today.end_of_day
               end

    start_date = if start_date.present?
                   tz.parse(start_date.to_s).beginning_of_day
                 else
                   (end_date - 7.days).beginning_of_day
                 end

    query = MarkingSession
            .where(user_id: user.id, unit_id: unit_id)
            .where(start_time: start_date..end_date)
            .order(:start_time)

    Entities::MarkingSessionEntity.represent(query).as_json
  end

  def get_marking_sessions_csv(start_date: nil, end_date: nil, timezone: nil)
    result = get_marking_sessions(start_date: start_date, end_date: end_date, timezone: timezone)

    tz = Time.zone
    tz = ActiveSupport::TimeZone[timezone] if timezone

    CSV.generate do |csv|
      # Add headers
      csv << [
        'Start Date',
        'Start Time',
        'End Date',
        'End Time',
        'Timezone',
        'Total Duration (m)',
        'Total Duration (h)',
        'Submissions Opened',
        'Comments Added',
        'Assessments Made',
        'During Tutorial'
      ]

      result.each do |row|
        start_time = row[:start_time].in_time_zone(tz)
        end_time   = row[:end_time].in_time_zone(tz)

        csv << [
          start_time.strftime('%Y-%m-%d %A'),
          start_time.strftime('%H:%M'),
          end_time.strftime('%Y-%m-%d %A'),
          end_time.strftime('%H:%M'),
          "#{tz.name} #{start_time.strftime('%:z')}",
          row[:duration_minutes],
          (row[:duration_minutes].to_f / 60).round(1),
          row[:submissions_opened],
          row[:comments_added],
          row[:assessments],
          row[:during_tutorial] ? 'TRUE' : 'FALSE'
        ]
      end
    end

  end

  def add_tutor_note(user, text, task_id = nil, reply_to_id = nil)
    text = text.strip
    return nil if user.nil? || text.nil? || text.empty?

    ln = tutor_notes.last

    # don't add if duplicate note
    return if ln && ln.user == user && ln.note == text

    note = TutorNote.create
    note.note = text
    note.user = user
    note.unit_role = self
    note.reply_to_id = reply_to_id
    note.task_id = task_id
    note.read_by_unit_role = false
    note.save!
    note
  end

  def should_moderate_task?(task)
    td = task.task_definition
    td_rep = TutorFeedbackScore.find_by(unit_role: self, task_definition: td)
    if td_rep.nil?
      td_rep = TutorFeedbackScore.create!({
                                            unit_role: self,
                                            task_definition: td,
                                            score: 50
                                          })
    end

    # We sample randomly during a task submission
    if rand(0..100) > td_rep.score
      return true
    end

    false
  end
end
