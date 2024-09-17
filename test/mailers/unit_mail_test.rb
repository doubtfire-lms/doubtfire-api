require 'test_helper'
require 'grade_helper'

class UnitMailTest < ActionMailer::TestCase
  def test_send_summary_email
    unit = FactoryBot.create :unit

    summary_stats = {}

    summary_stats[:week_end] = Time.zone.today
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

end
