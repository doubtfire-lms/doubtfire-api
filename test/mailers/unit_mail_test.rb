require 'test_helper'
require 'grade_helper'

class UnitMailTest < ActionMailer::TestCase

  def test_send_summary_email
    unit = FactoryBot.create :unit

    summary_stats = {}

    summary_stats[:week_end] = Date.today
    summary_stats[:week_start] = summary_stats[:week_end] - 7.days
    summary_stats[:weeks_comments] = TaskComment.where("created_at >= :start AND created_at < :end", start: summary_stats[:week_start], end: summary_stats[:week_end]).count
    summary_stats[:weeks_engagements] = TaskEngagement.where("engagement_time >= :start AND engagement_time < :end", start: summary_stats[:week_start], end: summary_stats[:week_end]).count

    unit.send_weekly_status_emails(summary_stats)

    assert_equal unit.active_projects.count + 1, ActionMailer::Base.deliveries.count
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
  end
  #The test below is an idea that would be able to help with testing the mailer and sending a email that would other wise sent to tother people did not receive
  #work as intended. More reseacrh and undertsnading would need to be done in order to get this to work properly
  #One of the main issues that was suspected was that it does not have a rake test file, hence the code did not work properly
  #but this sends another issue as the normal test documentation did not require a rake file.
  #2 options:
  #Option 1: Create a new a new type of rake file to make this thing work much better, but needs to be resaerch as it needs more context as to how rake files work with
  #the action mailer files of rails itself
  #Option 2: Create a new mailer system that would serve the purpose of testing the action mailer and a key concept of the mailer itself. but this has a flaw with itself
  #as it takes too much effort try and buld a mock system inside an already working system


  #Note: If you need the mailer to work correctly in the first place then "Please comment out the code below so that the other systems work properly"

  #Important note: if you wan to use this and are trying to get this to work , please replace the field "Youremail" with your email address

  def test_send_email
    test "mailer_sender" do
      # Initialization of mailer
      email = NotificationsMailer.create_invite("me@example.com",
                                      "Youremail", Time.now)

      # Sendmail
      assert_emails 1 do
        email.deliver_now
      end

      # Test the body of the email so it sends what we want the mailer to send
      assert_equal ["me@example.com"], email.from
      assert_equal ["youremail"], email.to
      assert_equal "You have been invited by me@example.com", email.subject
      assert_equal read_fixture("notifications_mailer").join, email.html_part.body.to_s.
    end
  end
end
