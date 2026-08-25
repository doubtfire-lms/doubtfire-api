# frozen_string_literal: true

class NotificationGroupBuilder
  SEVERITY_ORDER = {
    'critical' => 0,
    'warning' => 1,
    'normal' => 2
  }.freeze

  def initialize(notifications)
    @notifications = notifications.to_a
  end

  def groups
    @notifications
      .group_by { |notification| grouping_key(notification) }
      .values
      .map { |items| serialize(items) }
      .sort_by { |group| [group[:read] ? 1 : 0, SEVERITY_ORDER.fetch(group[:severity]), -group[:latest_at].to_f] }
  end

  private

  def grouping_key(notification)
    state_key = notification.read_at ? "read:#{notification.read_at.to_f}" : 'unread'
    return "#{state_key}:task:#{notification.task_id}" if notification.task_id.present?

    unit_role_id = notification.metadata['unit_role_id'] || notification.metadata[:unit_role_id]
    return "#{state_key}:tutor-notes:#{unit_role_id}" if Notification::MODERATION_KINDS.include?(notification.kind)

    "#{state_key}:unit:#{notification.unit_id}:#{notification.kind}"
  end

  def serialize(items)
    latest = items.max_by(&:created_at)
    task = latest.task
    counts = items.each_with_object(Hash.new(0)) { |notification, result| result[notification.kind] += 1 }
    latest_status = items
                    .select { |notification| notification.kind == 'task_status_changed' }
                    .max_by(&:created_at)
                    &.metadata
                    &.fetch('status', nil)
    tutor_notes = items
                  .select { |notification| Notification::MODERATION_KINDS.include?(notification.kind) }
                  .sort_by { |notification| [notification.created_at, notification.id] }

    {
      key: grouping_key(latest),
      notification_ids: items.map(&:id),
      tutor_note_notification_ids: tutor_notes.map(&:id),
      unit: {
        id: latest.unit.id,
        code: latest.unit.code,
        name: latest.unit.name
      },
      task: task_details(task, latest.recipient),
      counts: counts,
      event_count: items.count,
      latest_status: latest_status,
      severity: severity_for(items),
      read: items.all? { |notification| notification.read_at.present? },
      read_at: items.filter_map(&:read_at).max,
      latest_at: latest.created_at,
      tutor_note_ids: tutor_notes.filter_map { |notification| notification.metadata['tutor_note_id'] },
      tutor_note_unit_role_id: tutor_notes.first&.metadata&.fetch('unit_role_id', nil),
      overseer_assessment_id: overseer_assessment_id(items),
      detail: detail_for(counts, latest_status),
      summary: "#{subject_for(task, latest.recipient)} - #{detail_for(counts, latest_status)}"
    }
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
    return 'critical' if kinds.intersect?(%w[discuss_expired pdf_generation_failed])
    return 'warning' if kinds.intersect?(%w[discuss_warning overseer_failed] + Notification::MODERATION_KINDS)

    'normal'
  end

  # The newest failed run in the group, so opening the notification can jump
  # straight to that report.
  def overseer_assessment_id(items)
    items.select { |notification| notification.kind == 'overseer_failed' }.max_by(&:created_at)&.source_id
  end

  def subject_for(task, recipient)
    return 'Unit notification' if task.nil?

    return task.task_definition.abbreviation if task.project.student == recipient

    "#{task.task_definition.abbreviation} for #{task.project.student.name}"
  end

  # What happened, without the task it happened to, so callers can show the two
  # separately rather than splitting the summary back apart.
  def detail_for(counts, latest_status)
    details = []
    details << 'discussion deadline missed' if counts['discuss_expired'].positive?
    details << 'discussion deadline approaching' if counts['discuss_warning'].positive?
    details << 'submission PDF generation failed' if counts['pdf_generation_failed'].positive?
    details << 'overseer assessment failed' if counts['overseer_failed'].positive?
    moderation_notes = Notification::MODERATION_KINDS.sum { |kind| counts[kind] }
    details << pluralize(moderation_notes, 'moderation note') if moderation_notes.positive?
    details << pluralize(counts['new_task_comment'], 'new comment') if counts['new_task_comment'].positive?
    details << "task status changed to #{status_name(latest_status)}" if latest_status.present?

    # Sentence case, so a single detail reads as a heading and several still join
    # into one readable sentence.
    details.to_sentence.upcase_first
  end

  def status_name(status_key)
    TaskStatus.status_for_name(status_key.to_s)&.name || status_key.to_s.humanize
  end

  def pluralize(count, noun)
    "#{count} #{count == 1 ? noun : noun.pluralize}"
  end
end
