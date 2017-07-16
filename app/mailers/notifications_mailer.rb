class NotificationsMailer < ActionMailer::Base
  @doubtfire_host = Doubtfire::Application.config.institution[:host]
  @unsubscribe_url = "https://#{@doubtfire_host}/#/home?notifications"

  def weekly_student_summary(project, summary_stats)
    return nil if project.nil?

    @student = project.student
    @project = project
    @tutor = project.main_tutor
    @convenor = project.main_convenor
    @summary_stats = summary_stats

    @engagements = @project.task_engagements.where("task_engagements.engagement_time >= :start AND task_engagements.engagement_time < :end", start: summary_stats[:week_start], end: summary_stats[:week_end])

    @engagements_count = @engagements.count

    @student_engagements = @engagements.select { |e| [TaskStatus.not_started.name, TaskStatus.need_help.name, TaskStatus.working_on_it.name, TaskStatus.ready_to_mark.name].include? e.engagement  }.count

    @staff_engagements = @engagements.select { |e| [TaskStatus.complete.name, TaskStatus.do_not_resubmit.name, TaskStatus.redo.name, TaskStatus.discuss.name, TaskStatus.demonstrate.name, TaskStatus.fail.name].include? e.engagement  }.count

    @task_states = project.tasks.joins(:task_status).select("count(tasks.id) as number, task_statuses.name as status").group("task_statuses.name")

    @received_comments = project.comments.where("recipient_id = :student_id AND task_comments.created_at > :start", student_id: @student.id, start: Time.zone.today - 7.days).count
    @sent_comments = project.comments.where("user_id = :student_id AND task_comments.created_at > :start", student_id: @student.id, start: Time.zone.today - 7.days).count

    @top_tasks = project.top_tasks
    @overdue_top = @top_tasks.select {|tt| tt[:reason] == :overdue}
    @soon_top = @top_tasks.select {|tt| tt[:reason] == :soon}
    @ahead_top = @top_tasks.select {|tt| tt[:reason] == :ahead}

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

  helper_method :top_task_desc
  helper_method :were_was
end
