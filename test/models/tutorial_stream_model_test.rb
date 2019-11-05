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

  def test_delete_when_two_tutorial_stream
    unit = FactoryGirl.create(:unit)
    activity_type = FactoryGirl.create(:activity_type)
    tutorial_stream_first = unit.add_tutorial_stream('Practical-01', 'prac-01', activity_type)
    tutorial_stream_second = unit.add_tutorial_stream('Practical-02', 'prac-02', activity_type)

    # Add task definition to first tutorial stream
    task_def_first = unit.task_definitions.first
    task_def_first.tutorial_stream = tutorial_stream_first
    task_def_first.save!

    # Add task definition to second tutorial stream
    task_def_second = unit.task_definitions.second
    task_def_second.tutorial_stream = tutorial_stream_second
    task_def_second.save!

    assert_equal task_def_first, tutorial_stream_first.task_definitions.first
    assert_equal 1, tutorial_stream_first.task_definitions.count
    assert_equal task_def_second, tutorial_stream_second.task_definitions.first
    assert_equal 1, tutorial_stream_second.task_definitions.count

    tutorial_stream_first.destroy
    assert tutorial_stream_first.destroyed?

    assert_equal 1, unit.tutorial_streams.count
    assert_equal 2, unit.tutorial_streams.first.task_definitions.count
    assert_equal task_def_first, unit.tutorial_streams.first.task_definitions.first
    assert_equal task_def_second, unit.tutorial_streams.first.task_definitions.second
  end
end
