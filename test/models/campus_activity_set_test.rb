require "test_helper"

class CampusActivitySetTest < ActiveSupport::TestCase
  def campus_activity_set
    @campus_activity_set ||= CampusActivitySet.new
  end

  def test_valid
    assert campus_activity_set.valid?
  end
end
