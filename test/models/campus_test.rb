require "test_helper"

class CampusTest < ActiveSupport::TestCase
  def campus
    @campus ||= Campus.new
  end

  def test_valid
    assert campus.valid?
  end
end
