require 'test_helper'

class CommunicationsMailerTest < ActionMailer::TestCase
  def test_plain_text_email_contains_only_the_entered_body
    body = "Hello Ada,\n\nPlease review your work."
    message = communication_email(body: body, plain_text: true)

    assert_match %r{\Atext/plain}, message.content_type
    assert_nil message.html_part
    assert_equal body, message.body.decoded.gsub("\r\n", "\n")
  end

  def test_default_email_keeps_the_notification_layout
    message = communication_email(body: 'Please review your work.')

    assert message.html_part
    assert message.text_part
    assert_includes message.html_part.body.decoded, 'Notification'
  end

  private

  def communication_email(body:, plain_text: false)
    CommunicationsMailer.communication_email(
      to: 'student@example.com',
      from: 'convenor@example.com',
      subject: 'Reminder',
      body: body,
      recipient: nil,
      sender: nil,
      unit: nil,
      rule: nil,
      plain_text: plain_text
    )
  end
end
