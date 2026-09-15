# frozen_string_literal: true

class NotificationGroupBuilder
  EVENT_DETAILS = {
    'discuss_expired' => 'discussion deadline missed',
    'discuss_warning' => 'discussion deadline approaching',
    'pdf_generation_failed' => 'submission PDF generation failed',
    'overseer_failed' => 'overseer assessment failed',
    'portfolio_failed' => 'portfolio compilation failed',
    'portfolio_ready' => 'portfolio ready to review',
    'task_start_now' => 'ready to start now',
    'task_due_soon' => 'due within 5 days',
    'task_overdue' => 'past its due date'
  }.freeze

  def initialize(notifications)
    @notifications = notifications.to_a
  end

  def groups
    @notifications
      .group_by { |notification| grouping_key(notification) }
      .values
      .map { |items| build_group(items) }
      .sort_by { |group| -group[:latest_at].to_f }
  end

  private

  def grouping_key(notification)
    state_key = notification.read_at ? "read:#{notification.read_at.to_f}" : 'unread'
    return "#{state_key}:communication-email:#{notification.id}" if notification.kind == 'communication_email'
    return "#{state_key}:weekly-summary:#{notification.id}" if notification.kind == 'weekly_summary'

    # A moderation note belongs to one staff member's thread, so it groups by that
    # rather than joining the task's other notifications.
    return "#{state_key}:tutor-notes:#{notification.unit_role_id}:#{notification.task_id}" if Notification::MODERATION_KINDS.include?(notification.kind)
    if notification.kind == 'feedback_warning'
      return "#{state_key}:unit:#{notification.unit_id}:feedback-warning:#{feedback_warning_batch(notification)}"
    end

    return "#{state_key}:task:#{notification.task_id}" if notification.task_id.present?
    return "#{state_key}:portfolio:#{notification.project_id}" if Notification::PORTFOLIO_KINDS.include?(notification.kind)

    "#{state_key}:unit:#{notification.unit_id}:#{notification.kind}"
  end

  def build_group(items)
    latest = items.max_by(&:created_at)
    counts = items.each_with_object(Hash.new(0)) { |notification, result| result[notification.kind] += 1 }
    feedback_warning = counts['feedback_warning'].positive?
    task = feedback_warning ? nil : latest.task
    latest_status = items
                    .select { |notification| notification.kind == 'task_status_changed' }
                    .max_by(&:created_at)
                    &.task_status
                    &.status_key
    tutor_notes = items
                  .select { |notification| Notification::MODERATION_KINDS.include?(notification.kind) }
                  .sort_by { |notification| [notification.created_at, notification.id] }
    detail = detail_for(items, counts, latest_status)
    project = feedback_warning ? nil : (latest.project || task&.project)
    weekly_summary = latest.weekly_summary_data

    {
      key: grouping_key(latest),
      notification_ids: items.map(&:id),
      tutor_note_notification_ids: tutor_notes.map(&:id),
      unit: {
        id: latest.unit.id,
        code: latest.unit.code,
        name: latest.unit.name
      },
      project_id: project&.id,
      task: task_details(task, latest.recipient),
      destination: feedback_warning ? { type: 'unit_inbox', unit_id: latest.unit_id } : nil,
      counts: counts,
      event_count: items.count,
      latest_status: latest_status,
      severity: severity_for(items),
      read: items.all? { |notification| notification.read_at.present? },
      read_at: items.filter_map(&:read_at).max,
      latest_at: latest.created_at,
      timezone: project&.campus&.timezone || Time.zone.name,
      tutor_note_ids: tutor_notes.filter_map(&:tutor_note_id),
      tutor_note_unit_role_id: tutor_notes.first&.unit_role_id,
      tutor_note_on_task_tutor: tutor_note_on_task_tutor?(tutor_notes.first, task),
      overseer_assessment_id: overseer_assessment_id(items),
      message_subject: latest.message_subject,
      message_body: weekly_summary ? nil : latest.message_body,
      weekly_summary: weekly_summary,
      detail: detail,
      summary: "#{subject_for(task, latest.recipient, counts, latest)} - #{detail}"
    }
  end

  def feedback_warning_batch(notification)
    notification.email_sent_at ? "emailed:#{notification.email_sent_at.to_f}" : 'not-emailed'
  end

  # The task's Mod Notes tab shows the notes on its own tutor, so a note about
  # anyone else - a convenor's thread that happens to name this task - has to be
  # opened as a thread instead.
  def tutor_note_on_task_tutor?(notification, task)
    return false if notification.nil? || task.nil?

    tutor = task.project.tutor_for(task.task_definition)
    tutor.present? && tutor.id == notification.unit_role&.user_id
  end

  def task_details(task, recipient)
    return nil if task.nil?

    staff_view = task.project.student != recipient

    {
      id: task.id,
      project_id: task.project_id,
      task_definition_id: task.task_definition_id,
      abbreviation: task.task_definition.abbreviation,
      name: task.task_definition.name,
      staff_view: staff_view,
      student_name: staff_view ? task.project.student.name : nil
    }
  end

  def severity_for(items)
    kinds = items.map(&:kind)
    return 'critical' if kinds.intersect?(%w[discuss_expired pdf_generation_failed portfolio_failed task_overdue])
    return 'warning' if kinds.intersect?(%w[discuss_warning overseer_failed task_due_soon feedback_warning] + Notification::MODERATION_KINDS)

    'normal'
  end

  # The newest failed run in the group, so opening the notification can jump
  # straight to that report.
  def overseer_assessment_id(items)
    items.select { |notification| notification.kind == 'overseer_failed' }.max_by(&:created_at)&.overseer_assessment_id
  end

  def subject_for(task, recipient, counts, latest)
    return latest.message_subject.presence || 'Email message' if counts['communication_email'].positive?
    return latest.message_subject.presence || 'Weekly summary' if counts['weekly_summary'].positive?
    return 'Portfolio' if Notification::PORTFOLIO_KINDS.any? { |kind| counts[kind].positive? }
    return 'Feedback required' if counts['feedback_warning'].positive?
    return 'Unit notification' if task.nil?

    return task.task_definition.abbreviation if task.project.student == recipient

    "#{task.task_definition.abbreviation} for #{task.project.student.name}"
  end

  # What happened, without the task it happened to, so callers can show the two
  # separately rather than splitting the summary back apart.
  def detail_for(items, counts, latest_status)
    details = [
      communication_detail(items, counts),
      weekly_summary_detail(items, counts),
      feedback_warning_detail(counts),
      *event_details(counts),
      moderation_detail(items),
      comment_detail(counts),
      status_detail(latest_status)
    ].compact

    # Sentence case, so a single detail reads as a heading and several still join
    # into one readable sentence.
    details.to_sentence.upcase_first
  end

  def weekly_summary_detail(items, counts)
    return unless counts['weekly_summary'].positive?

    data = items.max_by(&:created_at).weekly_summary_data || {}
    if data['audience'] == 'staff'
      assessed = data.fetch('assessed_tasks', 0)
      awaiting = data.fetch('awaiting_feedback', 0)
      "You assessed #{pluralize(assessed, 'task')} and have #{pluralize(awaiting, 'task')} awaiting feedback"
    else
      received = data.fetch('received_comments', 0)
      activity = data.fetch('task_activity', 0)
      "You received #{pluralize(received, 'comment')} and had activity on #{pluralize(activity, 'task')} this week"
    end
  end

  def feedback_warning_detail(counts)
    count = counts['feedback_warning']
    return unless count.positive?

    "You have #{pluralize(count, 'task')} that #{count == 1 ? 'requires' : 'require'} feedback as soon as possible"
  end

  def communication_detail(items, counts)
    return unless counts['communication_email'].positive?

    sender = items.max_by(&:created_at).actor&.name
    sender.present? ? "Message from #{sender}" : 'Message'
  end

  def event_details(counts)
    EVENT_DETAILS.filter_map { |kind, detail| detail if counts[kind].positive? }
  end

  def moderation_detail(items)
    moderation_notifications = items.select { |notification| Notification::MODERATION_KINDS.include?(notification.kind) }
    return if moderation_notifications.empty?

    staff_names = moderation_notifications.filter_map { |notification| notification.actor&.name }.uniq
    detail = pluralize(moderation_notifications.count, 'moderation note')
    staff_names.any? ? "#{detail} from #{staff_names.to_sentence}" : detail
  end

  def comment_detail(counts)
    count = counts['new_task_comment']
    pluralize(count, 'new comment') if count.positive?
  end

  def status_detail(latest_status)
    "task status changed to #{status_name(latest_status)}" if latest_status.present?
  end

  def status_name(status_key)
    TaskStatus.status_for_name(status_key.to_s)&.name || status_key.to_s.humanize
  end

  def pluralize(count, noun)
    "#{count} #{count == 1 ? noun : noun.pluralize}"
  end
end
