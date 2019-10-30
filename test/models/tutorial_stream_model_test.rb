require "test_helper"

class TutorialStreamModelTest < ActiveSupport::TestCase
  def test_default_create
    tutorial_stream = FactoryGirl.create(:tutorial_stream)
    last_tutorial_stream = TutorialStream.last
    assert tutorial_stream.valid?
    assert_equal tutorial_stream, last_tutorial_stream
  end

  def test_specific_create
    tutorial_stream = FactoryGirl.create(:tutorial_stream, name: 'Seminar-01', abbreviation: 'sem-01')
    last_tutorial_stream = TutorialStream.last
    assert_equal(tutorial_stream.name, 'Seminar-01')
    assert_equal tutorial_stream.abbreviation, 'sem-01'
    assert tutorial_stream.valid?
    assert_equal tutorial_stream, last_tutorial_stream
  end

  def test_add_tutorial_stream
    unit = FactoryGirl.create(:unit)
    activity_type = FactoryGirl.create(:activity_type)
    tutorial_stream = unit.add_tutorial_stream('Practical-01', 'prac-01', activity_type)
    last_tutorial_stream = unit.tutorial_streams.last
    assert tutorial_stream.valid?
    assert_equal last_tutorial_stream, TutorialStream.last
    assert_equal tutorial_stream, last_tutorial_stream
  end
end
