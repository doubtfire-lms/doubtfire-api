require 'test_helper'
require 'grade_helper'

class ErrorLogMailerTest < ActionMailer::TestCase

  def test_can_send_error_log_mail
    Doubtfire::Application.config.email_errors_to = 'test <test@test.com>'
    begin
      raise 'test'
    rescue StandardError => e
      mail = ErrorLogMailer.error_message('test', 'test message', e)
    end

    assert mail.present?
    assert mail.to.include? 'test@test.com'
    assert mail.body.include? e.message
    assert mail.body.include? e.backtrace.join("\n")
  end

  def test_latex_error_logs_are_attached
    Doubtfire::Application.config.email_errors_to = 'test <test@test.com>'
    begin
      raise Task::LatexError.new('this is the content of the log'), 'test'
    rescue StandardError => e
      mail = ErrorLogMailer.error_message('test', 'test message', e)
    end

    assert mail.present?
    assert mail.to.include? 'test@test.com'
    assert mail.attachments['log.txt'].present?
    assert mail.attachments['log.txt'].body.include? 'this is the content of the log'
  end

  def test_portfolio_error_mail_keeps_student_details_and_latex_log
    Doubtfire::Application.config.email_errors_to = 'test <test@test.com>'
    details = '5928 - Test Example (example123) COURSE123'
    exception = Project::LatexError.new('full portfolio latex log')
    mail = ErrorLogMailer.error_message(
      "Failed portfolio job: #{details}",
      "Failed to create portfolio for project #{details}",
      exception
    )

    assert_includes mail.subject, details
    assert_includes mail.body.to_s, details
    assert_equal 'full portfolio latex log', mail.attachments['log.txt'].body.decoded
  end

  def test_can_send_error_log_mail_without_backtrace
    Doubtfire::Application.config.email_errors_to = 'test <test@test.com>'
    exception = StandardError.new('test')

    mail = ErrorLogMailer.error_message('test', 'test message', exception)

    assert mail.present?
    assert mail.to.include? 'test@test.com'
    assert mail.body.include? exception.message
    assert mail.body.include? 'No backtrace available'
  end
end
