# frozen_string_literal: true

require 'set'

class Notification < ApplicationRecord
  KINDS = %w[
    new_task_comment
    task_status_changed
    task_start_now
    task_due_soon
    task_overdue
    feedback_warning
    weekly_summary
    overseer_failed
    pdf_generation_failed
    discuss_warning
    discuss_expired
    moderation_note_added
    moderation_note_reply
    moderation_note_from_mentee
    portfolio_ready
    portfolio_failed
    communication_email
  ].freeze

  CHANNELS = %w[in_app email push].freeze

  MODERATION_KINDS = %w[moderation_note_added moderation_note_reply moderation_note_from_mentee].freeze
  PORTFOLIO_KINDS = %w[portfolio_ready portfolio_failed].freeze
  COMMUNICATION_KINDS = %w[communication_email].freeze
  TASK_DEADLINE_KINDS = %w[task_start_now task_due_soon task_overdue].freeze
  FEEDBACK_WARNING_KINDS = %w[feedback_warning].freeze

  belongs_to :recipient, class_name: 'User', inverse_of: :received_notifications
  belongs_to :unit
  belongs_to :project, optional: true
  belongs_to :task, optional: true
  belongs_to :actor, class_name: 'User', optional: true, inverse_of: :acted_notifications

  # What raised the notification.
  belongs_to :task_comment, optional: true
  belongs_to :overseer_assessment, optional: true
  belongs_to :tutor_note, optional: true

  # Extras, set only by the kinds that have them.
  belongs_to :task_status, optional: true
  belongs_to :unit_role, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :deduplication_key, presence: true, uniqueness: { scope: :recipient_id }

  scope :unread, -> { where(read_at: nil) }
  scope :recently_read, -> { where(read_at: 30.days.ago..) }
  scope :email_pending, -> { unread.where(email_processed_at: nil) }
  scope :email_ready, ->(at = Time.current) { where(email_not_before: [nil, ..at]) }

  def self.create_for_task_comment(comment)
    kind = kind_for_comment(comment)
    return if kind.nil?

    recipients_for_comment(comment).each do |recipient, recipient_task|
      # Use the read cursor rather than read_by?, which reports "read" for any
      # comment that does not require the user's attention. Status changes and
      # other attention_audience :none comments still need to raise notifications.
      next if comment.seen_by?(recipient)

      if kind == 'task_status_changed'
        resolve_for(recipient: recipient, task: recipient_task, kinds: kind)
      elsif kind == 'discuss_expired'
        resolve_for(recipient: recipient, task: recipient_task, kinds: 'discuss_warning')
      end

      create_event(
        recipient: recipient,
        unit: recipient_task.unit,
        project: recipient_task.project,
        task: recipient_task,
        actor: comment.user,
        kind: kind,
        task_comment: comment,
        deduplication_key: "task-comment:#{comment.id}:#{kind}",
        task_status: comment.is_a?(TaskStatusComment) ? comment.task_status : nil,
        discuss_deadline: discuss_deadline_for(comment, recipient_task)
      )
    end
  end

  def self.create_for_overseer(assessment)
    latest_assessment = assessment.task.overseer_assessments.order(created_at: :desc, id: :desc).first
    assessment_comment = assessment.latest_assessment_comment
    return unless assessment == latest_assessment && assessment.failed? && assessment_comment.present?

    student_task_recipients(assessment.task).each do |recipient, recipient_task|
      mark_read(
        where(
          recipient: recipient,
          task: recipient_task,
          kind: 'overseer_failed'
        ).where.not(overseer_assessment: assessment).unread
      )
      next if assessment_comment.seen_by?(recipient)

      create_event(
        recipient: recipient,
        unit: recipient_task.unit,
        project: recipient_task.project,
        task: recipient_task,
        actor: assessment.task.project.tutor_for(assessment.task.task_definition),
        kind: 'overseer_failed',
        overseer_assessment: assessment,
        deduplication_key: "overseer-assessment:#{assessment.id}:failed",
        email_not_before: assessment.updated_at + OverseerAssessment.student_notification_grace_period
      )
    end
  end

  def self.create_pdf_failure(task)
    version = task.file_uploaded_at&.to_i || task.updated_at.to_i

    student_task_recipients(task).each do |recipient, recipient_task|
      create_event(
        recipient: recipient,
        unit: recipient_task.unit,
        project: recipient_task.project,
        task: recipient_task,
        actor: task.project.tutor_for(task.task_definition),
        kind: 'pdf_generation_failed',
        deduplication_key: "pdf-generation:#{task.id}:#{version}:failed"
      )
    end
  end

  def self.create_for_tutor_note(tutor_note, recipient, kind)
    create_event(
      recipient: recipient,
      unit: tutor_note.unit_role.unit,
      project: tutor_note.task&.project,
      task: tutor_note.task,
      actor: tutor_note.user,
      kind: kind,
      tutor_note: tutor_note,
      unit_role: tutor_note.unit_role,
      deduplication_key: "tutor-note:#{tutor_note.id}"
    )
  end

  def self.create_for_portfolio(project, success:)
    recipient = project.student
    kind = success ? 'portfolio_ready' : 'portfolio_failed'
    notification = create_event(
      recipient: recipient,
      unit: project.unit,
      project: project,
      actor: project.main_convenor_user,
      kind: kind,
      deduplication_key: "portfolio:#{project.id}:#{project.updated_at.to_f}:#{kind}"
    )
    return if notification.nil?

    mark_read(
      where(recipient: recipient, project: project, kind: PORTFOLIO_KINDS)
        .where.not(id: notification.id)
        .unread
    )
    notification
  end

  # The communications system has already delivered this message as an email.
  # Record an in-app copy without passing it through the notification email
  # channel, which would send the recipient the same message twice.
  def self.create_for_communication_email(
    recipient:,
    unit:,
    project:,
    actor:,
    subject:,
    body:,
    deduplication_key:
  )
    create_event(
      recipient: recipient,
      unit: unit,
      project: project,
      actor: actor,
      kind: 'communication_email',
      message_subject: subject,
      message_body: body,
      deduplication_key: deduplication_key,
      channels: ['in_app']
    )
  end

  def self.create_weekly_summary(recipient:, unit:, data:, project: nil)
    week_start = Time.zone.parse(data.fetch(:week_start).to_s).to_date.iso8601
    audience = data.fetch(:audience)
    create_event(
      recipient: recipient,
      unit: unit,
      project: project,
      actor: unit.main_convenor_user,
      kind: 'weekly_summary',
      message_subject: "#{unit.code}: Weekly summary",
      message_body: JSON.generate(data),
      deduplication_key: "weekly-summary:#{unit.id}:#{audience}:#{week_start}"
    )
  end

  def self.create_event(**attributes)
    recipient = attributes.fetch(:recipient)
    unit = attributes.fetch(:unit)
    kind = attributes.fetch(:kind)
    deduplication_key = attributes.fetch(:deduplication_key)
    return if withdrawn_student?(attributes[:project], recipient)

    settings = NotificationSetting.for(recipient)
    channels = attributes[:channels] || settings.channels_for_unit_id(unit.id, kind)
    return if channels.empty?

    notification = find_or_initialize_by(
      recipient: recipient,
      deduplication_key: deduplication_key
    )
    return notification if notification.persisted?

    notification.assign_attributes(
      unit: unit,
      project: attributes[:project],
      task: attributes[:task],
      actor: attributes[:actor],
      kind: kind,
      task_comment: attributes[:task_comment],
      overseer_assessment: attributes[:overseer_assessment],
      tutor_note: attributes[:tutor_note],
      task_status: attributes[:task_status],
      unit_role: attributes[:unit_role],
      discuss_deadline: attributes[:discuss_deadline],
      email_not_before: attributes[:email_not_before],
      message_subject: attributes[:message_subject],
      message_body: attributes[:message_body]
    )
    notification.save!

    unless channels.include?('email')
      notification.update!(email_processed_at: Time.current)
    end

    notification
  rescue ActiveRecord::RecordNotUnique
    find_by(recipient: recipient, deduplication_key: deduplication_key)
  end

  def self.refresh_task_deadline_notifications!(now: Time.current)
    stale = where(kind: TASK_DEADLINE_KINDS).unread.includes(task: [:task_definition, { project: %i[unit campus user] }])
    stale.find_each do |notification|
      mark_read(where(id: notification.id)) unless notification.current_task_deadline?(now: now)
    end

    created = 0
    each_task_deadline_candidate(now: now) do |task|
      kind = task_deadline_kind(task, now: now)
      next if kind.nil?

      notification = create_event(
        recipient: task.student,
        unit: task.unit,
        project: task.project,
        task: task,
        kind: kind,
        deduplication_key: task_deadline_key(task, kind)
      )
      created += 1 if notification&.previously_new_record?
    end
    created
  end

  def self.refresh_feedback_warning_notifications!(now: Time.current, started_at: nil)
    stale = where(kind: FEEDBACK_WARNING_KINDS).unread.includes(
      :recipient,
      task: [
        :task_definition,
        {
          project: [
            :campus,
            { tutorial_enrolments: { tutorial: { unit_role: :user } } },
            { unit: [{ teaching_period: :breaks }, { main_convenor: :user }] }
          ]
        }
      ]
    )
    stale.find_each do |notification|
      mark_read(where(id: notification.id)) unless notification.current_feedback_warning?(now: now)
    end

    candidates = feedback_warning_candidates(now: now)
    existing = where(kind: FEEDBACK_WARNING_KINDS, task_id: candidates.select(:id))
               .pluck(:recipient_id, :deduplication_key)
               .to_set

    created = 0
    candidates.find_each do |task|
      next unless feedback_warning_eligible?(task, now: now, started_at: started_at)

      recipient = feedback_warning_recipient(task)
      next if recipient.nil?

      deduplication_key = feedback_warning_key(task)
      next if existing.include?([recipient.id, deduplication_key])

      notification = create_event(
        recipient: recipient,
        unit: task.unit,
        project: task.project,
        task: task,
        kind: 'feedback_warning',
        deduplication_key: deduplication_key
      )
      created += 1 if notification&.previously_new_record?
    end
    created
  end

  def self.task_deadline_kind(task, now: Time.current)
    return nil unless task_deadline_eligible?(task, now: now)

    today = now.in_time_zone(task.project.campus&.timezone.presence || Time.zone.name).to_date
    start_date = task.local_start_date.to_date
    due_date = task.local_due_date.to_date

    return 'task_overdue' if today > due_date
    return 'task_due_soon' if today >= due_date - 5.days
    return 'task_start_now' if today >= start_date

    nil
  end

  def self.task_deadline_key(task, kind)
    date = kind == 'task_start_now' ? task.local_start_date : task.local_due_date
    "task-deadline:#{task.id}:#{kind}:#{date.to_date.iso8601}"
  end

  def self.feedback_warning_key(task)
    "feedback-warning:#{task.id}:#{task.submission_date.utc.iso8601(6)}"
  end

  def self.feedback_warning_status_id
    @feedback_warning_status_id ||= TaskStatus.ready_for_feedback.id
  end

  # Moderation notifications stay unread until their recipient marks the tutor note itself as read.
  def self.mark_read(relation, at: Time.current, include_moderation: false)
    relation = relation.where.not(kind: MODERATION_KINDS) unless include_moderation

    # A group must share one exact read timestamp so read history can reconstruct the group.
    # rubocop:disable Rails/SkipsModelValidations
    relation.update_all(
      [
        'read_at = ?, email_processed_at = COALESCE(email_processed_at, ?), updated_at = ?',
        at,
        at,
        at
      ]
    )
    # rubocop:enable Rails/SkipsModelValidations
  end

  def self.mark_task_read(recipient, task)
    mark_read(where(recipient: recipient, task: task).unread)
  end

  def self.mark_tutor_note_read(recipient, tutor_note)
    mark_read(
      where(recipient: recipient, tutor_note: tutor_note).unread,
      include_moderation: true
    )
  end

  # Marking a comment unread rewinds the task's read cursor to the comment before
  # it, so every later comment on that task becomes unread too. Reopen all of
  # their notifications so the notification list agrees with the comment view.
  def self.reopen_from_comment(comment, recipient)
    later_comment_ids = TaskComment
                        .where(task_id: comment.task_id)
                        .where(id: comment.id..)
                        .select(:id)

    # Keep email_processed_at unchanged so manually reopening a comment never resends email.
    # rubocop:disable Rails/SkipsModelValidations
    where(recipient: recipient, task_comment_id: later_comment_ids)
      .update_all(read_at: nil, updated_at: Time.current)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def self.resolve_task_kinds(task, kinds)
    tasks = related_group_tasks(task)
    mark_read(where(task: tasks, kind: Array(kinds)).unread)
  end

  def self.resolve_for(recipient:, task:, kinds:)
    mark_read(where(recipient: recipient, task: task, kind: Array(kinds)).unread)
  end

  # A student who is no longer enrolled must not be notified about their old project.
  def self.withdrawn_student?(project, recipient)
    project.present? && !project.enrolled && project.user_id == recipient.id
  end

  def recipient_withdrawn?
    self.class.withdrawn_student?(project, recipient)
  end

  def weekly_summary_data
    return unless kind == 'weekly_summary' && message_body.present?

    JSON.parse(message_body)
  rescue JSON::ParserError
    nil
  end

  def email_ready?(at: Time.current)
    email_not_before.blank? || email_not_before <= at
  end

  def current_task_deadline?(now: Time.current)
    return true unless TASK_DEADLINE_KINDS.include?(kind)
    return false if task.nil?

    current_kind = self.class.task_deadline_kind(task, now: now)
    current_kind == kind && deduplication_key == self.class.task_deadline_key(task, kind)
  end

  def current_feedback_warning?(now: Time.current)
    return true unless FEEDBACK_WARNING_KINDS.include?(kind)
    return false if task.nil?

    self.class.feedback_warning_eligible?(task, now: now) &&
      self.class.feedback_warning_recipient(task) == recipient &&
      deduplication_key == self.class.feedback_warning_key(task)
  end

  def current_for_delivery?(now: Time.current)
    current_task_deadline?(now: now) && current_feedback_warning?(now: now)
  end

  def self.kind_for_comment(comment)
    case comment
    when TaskStatusComment
      return nil if student_actor?(comment)

      'task_status_changed'
    when DiscussTimeoutComment
      comment.content_type == DiscussTimeoutComment.expired ? 'discuss_expired' : 'discuss_warning'
    when AssessmentComment
      nil
    else
      # Automated bookkeeping comments - plan changes, check-ins, discussed-in-class,
      # feedback review requests - are attention_audience :none and raise no
      # notification. Status comments are :none as well, but they do notify and are
      # handled by the branch above.
      return nil if comment.attention_none?

      'new_task_comment'
    end
  end

  def self.discuss_deadline_for(comment, recipient_task)
    return nil unless comment.content_type == DiscussTimeoutComment.warning

    recipient_task.unit.discuss_timeout_expiry_date(recipient_task)
  end

  def self.recipients_for_comment(comment)
    if !student_actor?(comment) && comment.task.group_task? && comment.task.group_submission.present?
      student_task_recipients(comment.task)
    else
      [[comment.recipient, comment.task]]
    end
  end

  def self.student_task_recipients(task)
    related_group_tasks(task).filter_map do |recipient_task|
      student = recipient_task.project.student
      [student, recipient_task] unless student.nil?
    end
  end

  def self.related_group_tasks(task)
    return [task] unless task.group_task? && task.group_submission_id.present?

    Task.where(group_submission_id: task.group_submission_id).includes(project: :user).to_a
  end

  def self.student_actor?(comment)
    comment.user == comment.project.student || comment.task.role_for(comment.user).in?(%i[student group_member])
  end

  def self.each_task_deadline_candidate(now:)
    Unit.set_active.current_for_date(now).where(send_notifications: true).find_each do |unit|
      unit.active_projects.includes(:user, :campus).find_each do |project|
        project.assigned_task_defs.find_each do |task_definition|
          yield project.task_for_task_definition(task_definition)
        end
      end
    end
  end

  def self.feedback_warning_recipient(task)
    tutorial_enrolment = task.project.tutorial_enrolments.find do |enrolment|
      tutorial_stream_id = enrolment.tutorial.tutorial_stream_id
      tutorial_stream_id.nil? || tutorial_stream_id == task.task_definition.tutorial_stream_id
    end

    tutorial_enrolment&.tutorial&.unit_role&.user || task.unit.main_convenor_user
  end

  def self.feedback_warning_candidates(now:)
    Task
      .joins(:task_definition, project: :unit)
      .where(projects: { enrolled: true })
      .where(units: { active: true, send_notifications: true })
      .where('units.start_date <= :now AND units.end_date >= :now', now: now)
      .where(task_status_id: feedback_warning_status_id)
      .where.not(submission_date: nil)
      .where(
        'TIMESTAMPDIFF(DAY, tasks.submission_date, :now) >= units.feedback_warning_threshold_days',
        now: now
      )
      .where('projects.target_grade >= task_definitions.target_grade')
      .preload(
        :task_definition,
        project: [
          :campus,
          { tutorial_enrolments: { tutorial: { unit_role: :user } } },
          { unit: [{ teaching_period: :breaks }, { main_convenor: :user }] }
        ]
      )
  end

  def self.task_deadline_eligible?(task, now:)
    task.project.enrolled &&
      task.unit.active &&
      task.unit.send_notifications &&
      task.unit.start_date <= now &&
      task.unit.end_date >= now &&
      task.task_definition.target_grade <= task.project.target_grade &&
      task.submission_date.nil? &&
      !task.submitted_status?
  end

  def self.feedback_warning_eligible?(task, now:, started_at: nil)
    eligible =
      task.project.enrolled &&
      task.unit.active &&
      task.unit.send_notifications &&
      task.unit.start_date <= now &&
      task.unit.end_date >= now &&
      task.task_definition.target_grade <= task.project.target_grade &&
      task.task_status_id == feedback_warning_status_id &&
      task.submission_date.present? &&
      task.days_awaiting_feedback(now) >= task.unit.feedback_warning_threshold_days
    return false unless eligible
    return true if started_at.nil? || task.submission_date > started_at

    task.days_awaiting_feedback(started_at) < task.unit.feedback_warning_threshold_days
  end

  private_class_method :kind_for_comment, :discuss_deadline_for, :recipients_for_comment, :student_actor?,
                       :each_task_deadline_candidate, :task_deadline_eligible?, :feedback_warning_candidates
end
