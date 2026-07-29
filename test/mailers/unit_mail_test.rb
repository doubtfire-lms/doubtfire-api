require 'test_helper'
require 'grade_helper'

class UnitMailTest < ActionMailer::TestCase
  def test_send_summary_email
    unit = FactoryBot.create :unit

    summary_stats = {}

    summary_stats[:week_end] = Time.zone.now
    summary_stats[:week_start] = summary_stats[:week_end] - 7.days
    summary_stats[:weeks_comments] = TaskComment.where("created_at >= :start AND created_at < :end", start: summary_stats[:week_start], end: summary_stats[:week_end]).count
    summary_stats[:weeks_engagements] = TaskEngagement.where("engagement_time >= :start AND engagement_time < :end", start: summary_stats[:week_start], end: summary_stats[:week_end]).count

    unit.send_weekly_status_emails(summary_stats)

    assert_equal unit.active_projects.count + unit.staff.count, ActionMailer::Base.deliveries.count
    unit.destroy!
  end

  def test_send_portfolio_ready_from_main_convenor
    unit = FactoryBot.create :unit
    convenor = FactoryBot.create :user, :convenor

    ur = unit.employ_staff convenor, Role.convenor

    unit.update main_convenor: ur

    project = unit.active_projects.first

    mail = PortfolioEvidenceMailer.portfolio_ready(project)

    assert_equal 1, mail.from().count
    assert_equal convenor.email, mail.from().first
    assert mail.html_part.body.include? "projects/#{project.id}/portfolio"
    unit.destroy!
  end

  def test_send_portfolio_fail_from_main_convenor
    unit = FactoryBot.create :unit
    convenor = FactoryBot.create :user, :convenor

    ur = unit.employ_staff convenor, Role.convenor

    unit.update main_convenor: ur

    project = unit.active_projects.first

    mail = PortfolioEvidenceMailer.portfolio_failed(project)

    assert_equal 1, mail.from().count
    assert_equal convenor.email, mail.from().first
    assert mail.html_part.body.include? "projects/#{project.id}/portfolio"
    unit.destroy!
  end

  def test_send_overseer_assessment_failed_email
    unit = FactoryBot.create :unit
    convenor = FactoryBot.create :user, :convenor

    ur = unit.employ_staff convenor, Role.convenor

    unit.update main_convenor: ur

    project = unit.active_projects.first
    task = project.task_for_task_definition(unit.task_definitions.first)

    mail = PortfolioEvidenceMailer.overseer_assessment_failed(project, [task])

    assert_equal 1, mail.from.count
    assert_equal convenor.email, mail.from.first
    assert_equal project.student.email, mail.to.first
    assert mail.html_part.body.include? "projects/#{project.id}/dashboard/#{task.task_definition.abbreviation}"
  end

  def test_send_discussion_deadline_emails
    unit = FactoryBot.create(:unit)
    project = unit.active_projects.first
    task = project.task_for_task_definition(unit.task_definitions.first)
    sender = unit.main_convenor_user
    deadline = 7.days.from_now.to_date

    approaching = NotificationsMailer.discussion_deadline_approaching(task, sender, deadline)
    missed = NotificationsMailer.discussion_deadline_missed(task, sender)

    assert_equal project.student.email, approaching.to.first
    assert_includes approaching.subject, 'Discussion deadline approaching'
    assert_includes approaching.text_part.body.to_s, unit.formatted_discuss_timeout_date(deadline)
    assert_includes approaching.text_part.body.to_s, "projects/#{project.id}/dashboard/#{task.task_definition.abbreviation}"
    assert_equal 1, approaching.html_part.body.to_s.scan('<style type="text/css">').count
    assert_includes approaching.html_part.body.to_s, 'Unsubscribe'

    assert_equal project.student.email, missed.to.first
    assert_includes missed.subject, 'Discussion deadline missed'
    assert_includes missed.text_part.body.to_s, 'moved to Fix and Resubmit'
    assert_equal 1, missed.html_part.body.to_s.scan('<style type="text/css">').count
    assert_includes missed.html_part.body.to_s, 'Unsubscribe'
  end

  def test_discuss_timeout_notifications_send_emails
    unit = FactoryBot.create(
      :unit,
      discuss_timeout_enabled: true,
      discuss_timeout_warning_days: 7,
      discuss_timeout_expire_days: 14
    )
    project = unit.active_projects.first
    task = project.task_for_task_definition(unit.task_definitions.first)
    task.update!(task_status: TaskStatus.discuss)
    task.update!(moved_to_discuss_at: 8.days.ago)

    assert_equal 1, unit.notify_discuss_timeouts!
    assert_equal 1, SendImmediateNotificationJob.jobs.count

    approaching_job = SendImmediateNotificationJob.jobs.shift
    assert_emails 1 do
      SendImmediateNotificationJob.new.perform(*approaching_job['args'])
    end
    assert_includes ActionMailer::Base.deliveries.last.subject, 'Discussion deadline approaching'

    task.update!(moved_to_discuss_at: 15.days.ago)

    assert_equal 1, unit.notify_discuss_timeouts!
    assert_equal 1, SendImmediateNotificationJob.jobs.count

    missed_job = SendImmediateNotificationJob.jobs.shift
    assert_emails 1 do
      SendImmediateNotificationJob.new.perform(*missed_job['args'])
    end
    assert_includes ActionMailer::Base.deliveries.last.subject, 'Discussion deadline missed'
  end

end
