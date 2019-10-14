require "test_helper"

class ActivityTypeTest < ActiveSupport::TestCase
  def activity_type
    @activity_type ||= ActivityType.new
  end

  def test_valid
    assert activity_type.valid?
  end
end
