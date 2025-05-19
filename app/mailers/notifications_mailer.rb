class NotificationsMailer < ApplicationMailer

  # Load configuration values at class level
  def self.doubtfire_host
    Doubtfire::Application.config.institution[:host] || 'doubtfire.deakin.edu.au'
  end

  def self.doubtfire_product_name
    Doubtfire::Application.config.institution[:product_name] || 'Doubtfire'
  end

  def add_general
    @doubtfire_host = self.class.doubtfire_host
    @doubtfire_product_name = self.class.doubtfire_product_name
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

    @staff_engagements = @engagements.select { |e| [TaskStatus.complete.name, TaskStatus.feedback_exceeded.name, TaskStatus.redo.name, TaskStatus.discuss.name, TaskStatus.demonstrate.name, TaskStatus.fail.name].include? e.engagement }.count

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

  # Sends a summary email to the staff member who granted the extensions
  def extension_granted_summary(extensions, granted_by, total_selected, failed_extensions = [])
    @granted_by = granted_by
    @extensions = extensions
    @total_selected = total_selected
    @failed_extensions = failed_extensions
    @unit = extensions.any? ? extensions.first.task.unit : nil
    @is_tutor = true

    add_general

    email_with_name = %("#{@granted_by.name}" <#{@granted_by.email}>)
    # Set explicit from address using product name and a default sender
    from_address = %("#{self.class.doubtfire_product_name}" <no-reply@#{self.class.doubtfire_host}>)

    mail(
      to: email_with_name,
      from: from_address,
      subject: @unit ? "#{@unit.name}: Staff Grant Extensions" : "Staff Grant Extensions",
      template_name: 'extension_granted'
    )
  end

  # Sends a notification to a student about their granted extension
  def extension_granted_notification(extension, granted_by)
    @granted_by = granted_by
    @extension = extension
    @task = extension.task
    @student = extension.project.student
    @is_tutor = false

    add_general

    email_with_name = %("#{@student.name}" <#{@student.email}>)
    tutor_email = %("#{@granted_by.name}" <#{@granted_by.email}>)

    mail(
      to: email_with_name,
      from: tutor_email,
      subject: "#{@task.unit.name}: Extension granted for #{@task.task_definition.name}",
      template_name: 'extension_granted'
    )
  end

  # Main method to handle extension notifications from staff
  def extension_granted(extensions, granted_by, total_selected, failed_extensions = [], is_staff_grant = false)
    # Only send notifications for staff-granted bulk extensions
    return unless is_staff_grant && (extensions.any? || failed_extensions.any?)

    begin
      # Send summary to staff member who granted the extensions
      extension_granted_summary(extensions, granted_by, total_selected, failed_extensions).deliver_now

      # Send individual notifications only to students who have enabled email notifications
      extensions.each do |extension|
        student = extension.project.student
        if student.receive_task_notifications
          extension_granted_notification(extension, granted_by).deliver_now
        end
      end
    rescue => e
      Rails.logger.error "Failed to send extension notifications: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  helper_method :top_task_desc
  helper_method :were_was
  helper_method :are_is
  helper_method :this_these
end
