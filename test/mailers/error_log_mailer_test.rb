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
end
