require "test_helper"

class TutorialModelTest < ActiveSupport::TestCase

  def test_default_create
    tutorial = FactoryBot.build(:tutorial)
    assert tutorial.valid?

    tutorial_stream = FactoryBot.create(:tutorial_stream, unit: tutorial.unit)
    tutorial.tutorial_stream = tutorial_stream
    assert tutorial.valid?
    assert_equal tutorial.unit, tutorial_stream.unit
  end

  def test_unit_inconsistency_raises_error
    tutorial = FactoryBot.build(:tutorial)
    assert tutorial.valid?

    tutorial_stream = FactoryBot.create(:tutorial_stream)
    tutorial.tutorial_stream = tutorial_stream
    assert tutorial.invalid?
    assert_equal 'Unit should be same as the unit in the associated tutorial stream', tutorial.errors.full_messages.last
  end
end
