# frozen_string_literal: true

class Notification < ApplicationRecord
  KINDS = %w[
    feedback_left
    task_status_changed
    overseer_failed
    pdf_generation_failed
    discuss_warning
    discuss_expired
    tutor_note
  ].freeze

  DISCUSS_KINDS = %w[discuss_warning discuss_expired].freeze
  INTERNAL_COMMENT_TYPES = %w[assessment checked_in discussed_in_class plan].freeze

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
      next if comment.read_by?(recipient)

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
      next if assessment_comment.read_by?(recipient)

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

  def self.create_for_tutor_note(tutor_note, recipient)
    create_event(
      recipient: recipient,
      unit: tutor_note.unit_role.unit,
      project: tutor_note.task&.project,
      task: tutor_note.task,
      actor: tutor_note.user,
      kind: 'tutor_note',
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
    deduplication_key = attributes.fetch(:deduplication_key)
    preference = NotificationPreference.for(recipient, unit)

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
      kind: attributes.fetch(:kind),
      source: attributes[:source],
      metadata: attributes.fetch(:metadata, {})
    )
    notification.save!
    notification.update!(email_processed_at: Time.current) if preference.email_frequency == 'off'
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

  def self.reopen_for_source(source, recipient)
    # Keep email_processed_at unchanged so manually reopening a comment never resends email.
    # rubocop:disable Rails/SkipsModelValidations
    where(source: source, recipient: recipient).update_all(read_at: nil, updated_at: Time.current)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def self.resolve_task_kinds(task, kinds)
    tasks = related_group_tasks(task)
    mark_read(where(task: tasks, kind: Array(kinds)).unread)
  end

  def self.resolve_for(recipient:, task:, kinds:)
    mark_read(where(recipient: recipient, task: task, kind: Array(kinds)).unread)
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
      return nil if INTERNAL_COMMENT_TYPES.include?(comment.content_type)

      'feedback_left'
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
