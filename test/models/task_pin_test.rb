require "test_helper"

class TaskPinTest < ActiveSupport::TestCase
  def task_pin
    @task_pin ||= TaskPin.new
  end

  def test_valid
    assert task_pin.valid?
  end
end
