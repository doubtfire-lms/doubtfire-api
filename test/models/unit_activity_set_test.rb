require "test_helper"

class UnitActivitySetTest < ActiveSupport::TestCase
  def unit_activity_set
    @unit_activity_set ||= UnitActivitySet.new
  end

  def test_valid
    assert unit_activity_set.valid?
  end
end
