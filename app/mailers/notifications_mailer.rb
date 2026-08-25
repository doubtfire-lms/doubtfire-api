class NotificationsMailer < ApplicationMailer
  layout 'discussion_deadline_mailer',
         only: %i[discussion_deadline_approaching discussion_deadline_missed]

  def add_general
    @doubtfire_host = Doubtfire::Application.config.institution[:host]
    @doubtfire_product_name = Doubtfire::Application.config.institution[:product_name]
    @unsubscribe_url = "#{@doubtfire_host}/edit_profile"
  end

  def weekly_staff_summary(unit_role, summary_stats)
    return nil if unit_role.nil?

    add_general

    @staff = unit_role.user
    @unit_role = unit_role
    @unit = summary_stats[:unit]

    @received_comments = @unit.comments
                              .where("task_comments.recipient_id = :uid AND task_comments.created_at > :start", uid: @staff.id, start: 7.days.ago)
                              .where(content_type: [:text, :assessment, :audio, :image, :pdf, :discussion, :extension])
                              .count

    @sent_comments = @unit.comments
                          .where("task_comments.user_id = :uid AND task_comments.created_at > :start", uid: @staff.id, start: 7.days.ago)
                          .where(content_type: [:text, :assessment, :audio, :image, :pdf, :discussion, :extension])
                          .count

    @data = {
      sent_comments: @sent_comments, # Sent by tutor
      received_comments: @received_comments, # Received by tutor
      tasks_awaiting_feedback_count: summary_stats[:staff][unit_role.user][:tasks_awaiting_feedback_count], # For the tutor
      weekly_engagements_count: summary_stats[:staff][unit_role.user][:weekly_engagements_count], # Engagements from the student?
      staff_engagements: summary_stats[:staff][unit_role.user][:staff_engagements], # Engagements by the tutor
      oldest_task_days: summary_stats[:staff][unit_role.user][:oldest_task_days],
      weekly_total_tasks_discussed: summary_stats[:staff][unit_role.user][:weekly_total_tasks_discussed] # Total for the tutor for the week for the tutor
    }

    @convenor = @unit.main_convenor_user
    @summary_stats = summary_stats

    email_with_name = %("#{@staff.name}" <#{@staff.email}>)
    convenor_email = %("#{@convenor.name}" <#{@convenor.email}>)
    subject = "#{@unit.name}: Weekly Summary"

    mail(to: email_with_name, from: convenor_email, subject: subject)
  end

  def weekly_student_summary(project, summary_stats, did_revert_to_pass)
    return nil if project.nil?

    add_general

    @student = project.student
    @project = project
    @tutor = project.main_convenor_user
    @summary_stats = summary_stats
    @did_revert_to_pass = did_revert_to_pass

    @engagements = @project.task_engagements.where("task_engagements.engagement_time >= :start AND task_engagements.engagement_time < :end", start: summary_stats[:week_start], end: summary_stats[:week_end])

    @engagements_count = @engagements.count

    @student_engagements = @engagements.select { |e| [TaskStatus.not_started.name, TaskStatus.need_help.name, TaskStatus.working_on_it.name, TaskStatus.ready_for_feedback.name].include? e.engagement }.count

    @staff_engagements = @engagements.select { |e| [TaskStatus.complete.name, TaskStatus.feedback_exceeded.name, TaskStatus.redo.name, TaskStatus.discuss.name, TaskStatus.rediscuss.name, TaskStatus.attention_required.name, TaskStatus.demonstrate.name, TaskStatus.fail.name].include? e.engagement }.count

    @task_states = project.tasks.joins(:task_status).select("count(tasks.id) as number, task_statuses.name as status").group("task_statuses.name")

    @received_comments = project.comments.where("recipient_id = :student_id AND task_comments.created_at > :start", student_id: @student.id, start: Time.zone.now - 7.days).count
    @sent_comments = project.comments.where("user_id = :student_id AND task_comments.created_at > :start", student_id: @student.id, start: Time.zone.now - 7.days).count

    @top_tasks = project.top_tasks
    @overdue_top = @top_tasks.select { |tt| tt[:reason] == :overdue }
    @soon_top = @top_tasks.select { |tt| tt[:reason] == :soon }
    @ahead_top = @top_tasks.select { |tt| tt[:reason] == :ahead }

    email_with_name = %("#{@student.name}" <#{@student.email}>)
    tutor_email = %("#{@tutor.name}" <#{@tutor.email}>)
    subject = "#{project.unit.name}: Weekly Summary"

    mail(to: email_with_name, from: tutor_email, subject: subject)
  end

  def notification_digest(recipient, notifications)
    return nil if recipient.nil? || notifications.blank?

    add_general
    @recipient = recipient
    @notification_count = notifications.count
    @notification_url = "#{@doubtfire_host}/notifications"
    @units = notifications.group_by(&:unit).sort_by { |unit, _| unit.code }.map do |unit, for_unit|
      { unit: unit, groups: NotificationGroupBuilder.new(for_unit).groups }
    end
    @group_count = @units.sum { |section| section[:groups].count }

    subject = "#{@notification_count} new #{'change'.pluralize(@notification_count)} across #{@group_count} #{'notification'.pluralize(@group_count)}"
    mail(
      to: %("#{@recipient.name}" <#{@recipient.email}>),
      from: %("#{@doubtfire_product_name}" <no-reply@#{Doubtfire::Application.config.institution[:email_domain]}>),
      subject: subject
    )
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

  def top_task_desc(tt)
    "#{tt[:task_definition].abbreviation} - #{tt[:task_definition].name} #{"- which you need to discuss with your tutor" if tt[:status] == :discuss}"
  end

  def were_was(num)
    if num == 1
      "was"
    else
      "were"
    end
  end

  def are_is(num)
    if num == 1
      "is"
    else
      "are"
    end
  end

  def this_these(num)
    if num == 1
      "this"
    else
      "these"
    end
  end

  helper_method :top_task_desc
  helper_method :were_was
  helper_method :are_is
  helper_method :this_these

  private

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
