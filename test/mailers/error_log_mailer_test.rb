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
end
