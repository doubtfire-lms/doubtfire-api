require "test_helper"

class TutorialStreamModelTest < ActiveSupport::TestCase
  def test_default_create
    tutorial_stream = FactoryBot.create(:tutorial_stream)
    last_tutorial_stream = TutorialStream.last
    assert tutorial_stream.valid?
    assert_equal tutorial_stream, last_tutorial_stream
  end

  def test_specific_create
    tutorial_stream = FactoryBot.create(:tutorial_stream, name: 'Seminar-01', abbreviation: 'sem-01')
    last_tutorial_stream = TutorialStream.last
    assert_equal(tutorial_stream.name, 'Seminar-01')
    assert_equal tutorial_stream.abbreviation, 'sem-01'
    assert tutorial_stream.valid?
    assert_equal tutorial_stream, last_tutorial_stream
  end

  def test_add_tutorial_stream
    unit = FactoryBot.create(:unit, with_students: false)
    activity_type = FactoryBot.create(:activity_type)
    tutorial_stream = unit.add_tutorial_stream('Practical-01', 'prac-01', activity_type)
    last_tutorial_stream = unit.tutorial_streams.last
    assert tutorial_stream.valid?
    assert_equal last_tutorial_stream, TutorialStream.last
    assert_equal tutorial_stream, last_tutorial_stream
  end

  def test_delete_when_two_tutorial_streams_in_unit
    unit = FactoryBot.create(:unit, with_students: false)
    activity_type = FactoryBot.create(:activity_type)
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

    # Reload unit object to fetch from database
    unit.reload

    assert_equal 1, unit.tutorial_streams.count
    assert_equal 2, unit.tutorial_streams.first.task_definitions.count
    assert_equal task_def_first, unit.tutorial_streams.first.task_definitions.first
    assert_equal task_def_second, unit.tutorial_streams.first.task_definitions.second
  end

  def test_delete_when_three_tutorial_streams_in_unit
    unit = FactoryBot.create(:unit, with_students: false)
    activity_type = FactoryBot.create(:activity_type)
    tutorial_stream_first = unit.add_tutorial_stream('Practical-01', 'prac-01', activity_type)
    tutorial_stream_second = unit.add_tutorial_stream('Practical-02', 'prac-02', activity_type)
    tutorial_stream_third = unit.add_tutorial_stream('Practical-03', 'prac-03', activity_type)

    # Add task definition to first tutorial stream
    task_def_first = unit.task_definitions.first
    task_def_first.tutorial_stream = tutorial_stream_first
    task_def_first.save!

    # Add task definition to second tutorial stream
    task_def_second = unit.task_definitions.second
    task_def_second.tutorial_stream = tutorial_stream_second
    task_def_second.save!

    tutorial_stream_first.destroy
    assert_not tutorial_stream_first.destroyed?
    assert_equal 'cannot be deleted as it has task definitions associated with it, and it is not the last (or second last) tutorial stream', tutorial_stream_first.errors.full_messages.last
  end

  def test_delete_when_one_tutorial_stream_in_unit
    unit = FactoryBot.create(:unit, with_students: false)
    activity_type = FactoryBot.create(:activity_type)
    tutorial_stream_first = unit.add_tutorial_stream('Practical-01', 'prac-01', activity_type)

    # Add task definition to first tutorial stream
    task_def_first = unit.task_definitions.first
    task_def_first.tutorial_stream = tutorial_stream_first
    task_def_first.save!

    # Add task definition to second tutorial stream
    task_def_second = unit.task_definitions.second
    task_def_second.tutorial_stream = tutorial_stream_first
    task_def_second.save!

    tutorial_stream_first.destroy

    # Check whether object is destroyed
    assert tutorial_stream_first.destroyed?

    # Check whether task definition is still present
    unit.reload
    assert_not_nil unit.task_definitions.first
    assert_not_nil unit.task_definitions.second

    # Check task definitions' tutorial stream is nil
    assert_nil task_def_first.reload.tutorial_stream
    assert_nil task_def_second.reload.tutorial_stream
  end

  def test_creating_first_tutorial_stream_in_unit
    unit = FactoryBot.create(:unit, with_students: false)
    activity_type = FactoryBot.create(:activity_type)
    tutorial_stream_first = unit.add_tutorial_stream('Practical-01', 'prac-01', activity_type)

    assert_equal 1, unit.tutorial_streams.count
    assert_equal unit.task_definitions.count, tutorial_stream_first.task_definitions.count
  end

  def test_creating_second_tutorial_stream_in_unit
    unit = FactoryBot.create(:unit, with_students: false)
    activity_type = FactoryBot.create(:activity_type)
    tutorial_stream_first = unit.add_tutorial_stream('Practical-01', 'prac-01', activity_type)
    tutorial_stream_second = unit.add_tutorial_stream('Practical-02', 'prac-02', activity_type)

    assert_equal 2, unit.tutorial_streams.count
    assert_equal unit.task_definitions.count, tutorial_stream_first.task_definitions.count
    assert_empty tutorial_stream_second.task_definitions
  end

  def test_delete_with_tutorials
    unit = FactoryBot.create(:unit, with_students: false, stream_count: 1, campus_count: 2)

    assert_equal 1, unit.tutorial_streams.count
    assert_equal 1, unit.tutorial_streams.last.tutorials.count
    assert_equal 2, unit.tutorials.count
    
    unit.tutorial_streams.last.destroy!

    assert_equal 0, unit.tutorial_streams.count
    assert_equal 1, unit.tutorials.count
  end
end
