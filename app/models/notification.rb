# frozen_string_literal: true

class Notification < ApplicationRecord
  KINDS = %w[
    new_task_comment
    task_status_changed
    overseer_failed
    pdf_generation_failed
    discuss_warning
    discuss_expired
    moderation_note_added
    moderation_note_reply
    moderation_note_from_mentee
  ].freeze

  CHANNELS = %w[in_app email push].freeze

  DISCUSS_KINDS = %w[discuss_warning discuss_expired].freeze
  MODERATION_KINDS = %w[moderation_note_added moderation_note_reply moderation_note_from_mentee].freeze

  attribute :metadata, :json, default: -> { {} }

  belongs_to :recipient, class_name: 'User', inverse_of: :received_notifications
  belongs_to :unit
  belongs_to :project, optional: true
  belongs_to :task, optional: true
  belongs_to :actor, class_name: 'User', optional: true, inverse_of: :acted_notifications
  belongs_to :source, polymorphic: true, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :deduplication_key, presence: true, uniqueness: { scope: :recipient_id }
  validate :metadata_is_an_object

  scope :unread, -> { where(read_at: nil) }
  scope :recently_read, -> { where(read_at: 30.days.ago..) }
  scope :email_pending, -> { unread.where(email_processed_at: nil) }

  before_validation :normalize_metadata

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

      notification = create_event(
        recipient: recipient,
        unit: recipient_task.unit,
        project: recipient_task.project,
        task: recipient_task,
        actor: comment.user,
        kind: kind,
        source: comment,
        deduplication_key: "task-comment:#{comment.id}:#{kind}",
        metadata: metadata_for_comment(comment, recipient_task)
      )

      SendImmediateNotificationJob.perform_async(notification.id) if notification && DISCUSS_KINDS.include?(kind)
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
        ).where.not(source: assessment).unread
      )
      next if assessment_comment.seen_by?(recipient)

      create_event(
        recipient: recipient,
        unit: recipient_task.unit,
        project: recipient_task.project,
        task: recipient_task,
        actor: assessment.task.project.tutor_for(assessment.task.task_definition),
        kind: 'overseer_failed',
        source: assessment,
        deduplication_key: "overseer-assessment:#{assessment.id}:failed",
        metadata: {
          email_not_before: (
            assessment.updated_at + OverseerAssessment.student_notification_grace_period
          ).iso8601
        }
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
        source: task,
        deduplication_key: "pdf-generation:#{task.id}:#{version}:failed",
        metadata: {}
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
      source: tutor_note,
      deduplication_key: "tutor-note:#{tutor_note.id}",
      metadata: {
        unit_role_id: tutor_note.unit_role_id,
        tutor_note_id: tutor_note.id
      }
    )
  end

  def self.create_event(**attributes)
    recipient = attributes.fetch(:recipient)
    unit = attributes.fetch(:unit)
    kind = attributes.fetch(:kind)
    deduplication_key = attributes.fetch(:deduplication_key)
    return if withdrawn_student?(attributes[:project], recipient)

    settings = NotificationSetting.for(recipient)
    channels = settings.channels_for_unit(unit.id, kind)
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
      source: attributes[:source],
      metadata: attributes.fetch(:metadata, {})
    )
    notification.save!
    notification.update!(email_processed_at: Time.current) unless channels.include?('email')
    notification
  rescue ActiveRecord::RecordNotUnique
    find_by(recipient: recipient, deduplication_key: deduplication_key)
  end

  def self.mark_read(relation, at: Time.current)
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
    where(recipient: recipient, source_type: 'TaskComment', source_id: later_comment_ids)
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

  def email_ready?(at: Time.current)
    email_not_before = metadata['email_not_before'] || metadata[:email_not_before]
    return true if email_not_before.blank?

    Time.zone.parse(email_not_before) <= at
  rescue ArgumentError, TypeError
    true
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

  def self.metadata_for_comment(comment, recipient_task)
    result = {}
    result[:status] = comment.task_status.status_key if comment.is_a?(TaskStatusComment)
    result[:deadline] = recipient_task.unit.discuss_timeout_expiry_date(recipient_task)&.iso8601 if comment.content_type == DiscussTimeoutComment.warning
    result
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

  def metadata_is_an_object
    errors.add(:metadata, 'must be a JSON object') unless metadata.is_a?(Hash)
  end

  def normalize_metadata
    self.metadata ||= {}
    return unless metadata.is_a?(String)

    parsed = JSON.parse(metadata)
    self.metadata = parsed if parsed.is_a?(Hash)
  rescue JSON::ParserError
    nil
  end

  private_class_method :kind_for_comment, :metadata_for_comment, :recipients_for_comment, :student_actor?
end
