require 'test_helper'

class OverseerStepTest < ActiveSupport::TestCase
  def test_requires_database_backed_text_fields
    overseer_step = OverseerStep.new(timeout: 30, sort_order: 0)

    assert_not overseer_step.valid?
    assert_includes overseer_step.errors[:name], "can't be blank"
    assert_includes overseer_step.errors[:display_name], "can't be blank"
    assert_includes overseer_step.errors[:step_type], "can't be blank"
  end
end
