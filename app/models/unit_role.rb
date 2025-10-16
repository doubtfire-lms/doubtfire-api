class UnitRole < ApplicationRecord
  # Model associations
  belongs_to :unit, optional: false    # Foreign key
  belongs_to :user, optional: false    # Foreign key

  belongs_to :role, optional: false    # Foreign key

  has_many :tutorials, class_name: 'Tutorial', dependent: :nullify
  has_many :projects, through: :tutorials
  has_many :tasks, through: :projects
  has_many :task_engagements, through: :tasks
  has_many :comments, through: :tasks

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
    tasks_awaiting_feedback.order("submission_date ASC").first
  end

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
      :get
    ]
    # What can convenors do with unit roles?
    convenor_role_permissions = [
      :get,
      :delete
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
    data[:staff_engagements] = weekly_engagements.where(engagement: [TaskStatus.complete.name, TaskStatus.feedback_exceeded.name, TaskStatus.redo.name, TaskStatus.discuss.name, TaskStatus.demonstrate.name, TaskStatus.fail.name])

    # Weekly task engagements for this tutorial
    data[:weekly_engagements_count] = weekly_engagements.count

    tutorial_tasks = tasks_awaiting_feedback
      .joins(task_definition: :tutorial_stream)
      .joins(project: { tutorial_enrolments: :tutorial })
      .where(tutorials: { id: tutorial.id })
      .where(task_definitions: { tutorial_stream_id: tutorial_stream.id })
      .distinct

    if tutorial_tasks.count > 0
      data[:oldest_task_days] = (Time.zone.now - tutorial_tasks.order("submission_date ASC").first.submission_date.to_time).to_i / 1.day
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

    Entities::MarkingSessionEntity.represent(query).as_json
  end

  def get_marking_sessions_csv(start_date: nil, end_date: nil, timezone: nil)
    result = get_marking_sessions(start_date: start_date, end_date: end_date, timezone: timezone)

    tz = Time.zone
    tz = ActiveSupport::TimeZone[timezone] if timezone

    CSV.generate do |csv|
      # Add headers
      csv << ([
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
      ])

      result.each do |row|
        start_time = row[:start_time].in_time_zone(tz)
        end_time   = row[:end_time].in_time_zone(tz)

        csv << ([
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
        ])
      end
    end

  end
end
