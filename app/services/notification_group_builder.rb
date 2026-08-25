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
      summary: summary_for(task, latest.recipient, counts, latest_status)
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

  def summary_for(task, recipient, counts, latest_status)
    details = []
    details << 'discussion deadline missed' if counts['discuss_expired'].positive?
    details << 'discussion deadline approaching' if counts['discuss_warning'].positive?
    details << 'submission PDF generation failed' if counts['pdf_generation_failed'].positive?
    details << 'automated assessment failed' if counts['overseer_failed'].positive?
    moderation_notes = Notification::MODERATION_KINDS.sum { |kind| counts[kind] }
    details << pluralize(moderation_notes, 'moderation note') if moderation_notes.positive?
    details << pluralize(counts['new_task_comment'], 'new comment') if counts['new_task_comment'].positive?
    details << "status changed to #{latest_status.to_s.humanize}" if latest_status.present?

    subject =
      if task
        task.project.student == recipient ? task.task_definition.abbreviation : "#{task.task_definition.abbreviation} for #{task.project.student.name}"
      else
        'Unit notification'
      end
    "#{subject} - #{details.to_sentence}"
  end

  def pluralize(count, noun)
    "#{count} #{count == 1 ? noun : noun.pluralize}"
  end
end
