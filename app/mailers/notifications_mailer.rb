class NotificationsMailer < ApplicationMailer
  TASK_DEADLINE_SECTIONS = [
    ['task_start_now', 'Tasks ready to start'],
    ['task_due_soon', 'Tasks due within five days'],
    ['task_overdue', 'Tasks past due']
  ].freeze

  layout 'discussion_deadline_mailer',
         only: %i[discussion_deadline_approaching discussion_deadline_missed]

  def add_general
    @doubtfire_host = Doubtfire::Application.config.institution[:host]
    @doubtfire_product_name = Doubtfire::Application.config.institution[:product_name]
    @unsubscribe_url = "#{@doubtfire_host}/notifications/settings"
  end

  def notification_digest(recipient, notifications)
    return nil if recipient.nil? || notifications.blank?

    add_general
    @recipient = recipient
    @notification_url = "#{@doubtfire_host}/notifications"
    @units = notifications.group_by(&:unit).sort_by { |unit, _| unit.code }.map do |unit, for_unit|
      groups = NotificationGroupBuilder.new(for_unit).groups
      add_task_deadline_due_dates!(groups, for_unit)
      deadline_groups = TASK_DEADLINE_SECTIONS.map do |kind, heading|
        { heading: heading, kind: kind, groups: groups.select { |group| group[:counts][kind].positive? } }
      end
      deadline_groups.select! { |section| section[:groups].any? }
      grouped_deadline_notifications = deadline_groups.flat_map { |section| section[:groups] }
      other_groups = groups.reject { |group| grouped_deadline_notifications.include?(group) }
      group_sections = deadline_groups.dup
      if other_groups.any?
        group_sections << {
          heading: deadline_groups.any? ? 'Task updates' : nil,
          divider: deadline_groups.any?,
          kind: nil,
          groups: other_groups
        }
      end

      { unit: unit, groups: groups, group_sections: group_sections }
    end
    # Grouped events, so the count matches the rows the reader can see below.
    @notification_count = @units.sum { |section| section[:groups].count }

    subject = "#{@notification_count} new #{'notification'.pluralize(@notification_count)}"
    mail(
      to: %("#{@recipient.name}" <#{@recipient.email}>),
      from: %("#{@doubtfire_product_name}" <no-reply@#{Doubtfire::Application.config.institution[:email_domain]}>),
      subject: subject
    )
  end

  def notification_timestamp(group)
    time = group[:latest_at].in_time_zone(group[:timezone])
    "#{time.day.ordinalize} #{time.strftime('%B %Y at %H:%M')}"
  end

  def notification_due_date(group)
    due_date = group.dig(:task, :due_date)
    "Due #{due_date.day.ordinalize} #{due_date.strftime('%B')}"
  end

  def discussion_deadline_approaching(task, sender, expiry_date)
    add_discussion_deadline_details(task, sender)
    @deadline = task.unit.formatted_discuss_timeout_date(expiry_date)

    mail(
      to: %("#{@student.name}" <#{@student.email}>),
      from: %("#{@sender.name}" <#{@sender.email}>),
      subject: "#{@unit.code}: Discussion deadline approaching for #{@task.task_definition.abbreviation}"
    )
  end

  def discussion_deadline_missed(task, sender)
    add_discussion_deadline_details(task, sender)

    mail(
      to: %("#{@student.name}" <#{@student.email}>),
      from: %("#{@sender.name}" <#{@sender.email}>),
      subject: "#{@unit.code}: Discussion deadline missed for #{@task.task_definition.abbreviation}"
    )
  end

  helper_method :notification_timestamp
  helper_method :notification_due_date
  helper_method :weekly_summary_period

  private

  def weekly_summary_period(summary)
    from = Time.zone.parse(summary.fetch('week_start'))
    to = Time.zone.parse(summary.fetch('week_end'))
    "#{from.day.ordinalize} #{from.strftime('%B')} to #{to.day.ordinalize} #{to.strftime('%B %Y')}"
  end

  def add_task_deadline_due_dates!(groups, notifications)
    due_dates = notifications.filter_map do |notification|
      next unless Notification::TASK_DEADLINE_KINDS.include?(notification.kind) && notification.task.present?

      [notification.task_id, notification.task.local_due_date.to_date]
    end.to_h

    groups.each do |group|
      task = group[:task]
      task[:due_date] = due_dates[task[:id]] if task.present? && due_dates.key?(task[:id])
    end
  end

  def add_discussion_deadline_details(task, sender)
    add_general
    @task = task
    @project = task.project
    @unit = task.unit
    @student = @project.student
    @sender = sender
    @task_url = "#{@doubtfire_host}/projects/#{@project.id}/dashboard/#{@task.task_definition.abbreviation}"
  end
end
