require "test_helper"

class EnrolmentTest < ActiveSupport::TestCase
  def enrolment
    @enrolment ||= Enrolment.new
  end

  def test_valid
    assert enrolment.valid?
  end
end
