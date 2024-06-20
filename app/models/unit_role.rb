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
  def populate_summary_stats(summary_stats)
    data = {}

    data[:staff] = user
    data[:unit_role] = self

    data[:engagements] = task_engagements
                         .where(
                           "task_engagements.engagement_time >= :start AND task_engagements.engagement_time < :end",
                           start: summary_stats[:week_start], end: summary_stats[:week_end]
                         )

    data[:total_engagements_count] = task_engagements.count
    data[:weekly_engagements_count] = data[:engagements].count

    if tasks_awaiting_feedback.count > 0
      data[:oldest_task_days] = (Time.zone.today - tasks_awaiting_feedback.order("submission_date ASC").first.submission_date.to_date).to_i
      data[:tasks_awaiting_feedback_count] = tasks_awaiting_feedback.count
    else
      data[:oldest_task_days] = 0
      data[:tasks_awaiting_feedback_count] = 0
    end

    data[:number_of_students] = number_of_students

    data[:total_staff_engagements] = task_engagements.where(engagement: [TaskStatus.complete.name, TaskStatus.feedback_exceeded.name, TaskStatus.redo.name, TaskStatus.discuss.name, TaskStatus.demonstrate.name, TaskStatus.fail.name]).count
    data[:staff_engagements] = data[:engagements].where(engagement: [TaskStatus.complete.name, TaskStatus.feedback_exceeded.name, TaskStatus.redo.name, TaskStatus.discuss.name, TaskStatus.demonstrate.name, TaskStatus.fail.name]).count

    data[:received_comments] = comments.where("recipient_id = :staff_id AND task_comments.created_at > :start", staff_id: data[:staff].id, start: Time.zone.today - 7.days).count
    data[:sent_comments] = comments.where("task_comments.user_id = :staff_id AND task_comments.created_at > :start", staff_id: data[:staff].id, start: Time.zone.today - 7.days).count
    data[:total_comments] = comments.where("task_comments.user_id = :staff_id", staff_id: data[:staff].id).count

    summary_stats[:staff][self] = data
  end

  def send_weekly_status_email(summary_stats)
    return unless user.receive_feedback_notifications

    NotificationsMailer.weekly_staff_summary(self, summary_stats).deliver_now
  end

  def ensure_valid_user_for_role
    if is_convenor?
      errors.add :user, 'must have a role that is able to administer units (request admin to adjust user role)' unless user.has_convenor_capability?
    else
      errors.add :user, 'must have a role that is able to teach units (request admin to adjust user role)' unless user.has_tutor_capability?
    end
  end

  def is_main_convenor?
    unit.main_convenor_id == id
  end

  def ensure_convenor
    errors.add(:user, 'must retain current role to administer units as they are currently the main contact for the unit') unless is_convenor?
  end
end
