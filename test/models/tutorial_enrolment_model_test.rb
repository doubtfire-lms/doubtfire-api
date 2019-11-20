require "test_helper"

class TutorialEnrolmentModelTest < ActiveSupport::TestCase
  def test_default_create
    tutorial_enrolment = FactoryGirl.build(:tutorial_enrolment)
    assert tutorial_enrolment.valid?
    assert_equal tutorial_enrolment.project.unit, tutorial_enrolment.tutorial.unit
    assert_equal tutorial_enrolment.project.campus, tutorial_enrolment.tutorial.campus

    tutorial_enrolment = FactoryGirl.create(:tutorial_enrolment)
    assert tutorial_enrolment.valid?
    assert_equal tutorial_enrolment.project.unit, tutorial_enrolment.tutorial.unit
    assert_equal tutorial_enrolment.project.campus, tutorial_enrolment.tutorial.campus
  end

  def test_specific_create
    unit = FactoryGirl.create(:unit)
    campus = FactoryGirl.create(:campus)
    project = FactoryGirl.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial = FactoryGirl.create(:tutorial, unit: unit, campus: campus)
    tutorial_enrolment = FactoryGirl.build(:tutorial_enrolment, project: project)
    tutorial_enrolment.tutorial = tutorial
    tutorial_enrolment.save!

    assert_equal tutorial_enrolment.project, project
    assert_equal tutorial_enrolment.tutorial, tutorial
    assert tutorial_enrolment.valid?
  end

  def test_project_plus_tutorial_is_unique
    unit = FactoryGirl.create(:unit)
    campus = FactoryGirl.create(:campus)
    project = FactoryGirl.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial = FactoryGirl.create(:tutorial, unit: unit, campus: campus)

    tutorial_enrolment = FactoryGirl.build(:tutorial_enrolment, project: project)
    tutorial_enrolment.tutorial = tutorial
    tutorial_enrolment.save!

    tutorial_enrolment = FactoryGirl.build(:tutorial_enrolment, project: project)
    tutorial_enrolment.tutorial = tutorial
    assert tutorial_enrolment.invalid?

    # Unique, multiple tutorials (with no stream) and max one validation will fail
    assert_equal 'Tutorial already exists for the selected student', tutorial_enrolment.errors.full_messages.first
    assert_equal 'Project cannot have more than one enrolment when it is enrolled in tutorial with no stream', tutorial_enrolment.errors.full_messages.second
  end

  def test_enrol_in_tutorial
    unit = FactoryGirl.create(:unit)
    campus = FactoryGirl.create(:campus)
    project = FactoryGirl.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial = FactoryGirl.create(:tutorial, unit: unit, campus: campus)
    tutorial_enrolment = project.enrol_in(tutorial)
    assert tutorial_enrolment.valid?
    assert_equal tutorial_enrolment.project, project
    assert_equal tutorial_enrolment.tutorial, tutorial
  end

  def test_enrolling_twice_in_same_tutorial_stream_updates_enrolment
    unit = FactoryGirl.create(:unit)
    campus = FactoryGirl.create(:campus)
    project = FactoryGirl.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial_stream = FactoryGirl.create(:tutorial_stream, unit: unit)
    tutorial_first = FactoryGirl.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: campus)
    tutorial_second = FactoryGirl.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: campus)

    # Confirm that both tutorials have same tutorial stream
    assert_equal tutorial_stream, tutorial_first.tutorial_stream
    assert_equal tutorial_stream, tutorial_second.tutorial_stream

    # Enrol project in tutorial first
    tutorial_enrolment_first = project.enrol_in(tutorial_first)
    assert_equal tutorial_first, tutorial_enrolment_first.tutorial
    assert_equal project, tutorial_enrolment_first.project

    # Enrol again in tutorial stream and check that it updates the tutorial enrolment rather than creating a new one
    tutorial_enrolment_second = project.enrol_in(tutorial_second)
    assert_equal tutorial_second, tutorial_enrolment_second.tutorial
    assert_equal tutorial_enrolment_first.id, tutorial_enrolment_second.id
  end

  def test_enrolling_twice_when_tutorial_stream_is_null
    unit = FactoryGirl.create(:unit)
    campus = FactoryGirl.create(:campus)
    project = FactoryGirl.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial_stream = nil
    tutorial_first = FactoryGirl.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: campus)
    tutorial_second = FactoryGirl.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: campus)
    tutorial_third = FactoryGirl.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: campus)

    # Confirm that tutorial stream is nil
    assert_nil tutorial_first.tutorial_stream
    assert_nil tutorial_second.tutorial_stream

    # Enrol project in tutorial first
    tutorial_enrolment_first = project.enrol_in(tutorial_first)
    assert_equal tutorial_first, tutorial_enrolment_first.tutorial
    assert_equal project, tutorial_enrolment_first.project

    # Enrol again in tutorial stream and check that it updates the tutorial enrolment rather than creating a new one
    tutorial_enrolment_second = project.enrol_in(tutorial_second)
    assert_equal tutorial_second, tutorial_enrolment_second.tutorial
    assert_equal tutorial_enrolment_first.id, tutorial_enrolment_second.id

    # Manually create a tutorial enrolment
    tutorial_enrolment_third = FactoryGirl.build(:tutorial_enrolment, project: project)
    tutorial_enrolment_third.tutorial = tutorial_third
    assert tutorial_enrolment_third.invalid?
    assert_equal 'Project cannot have more than one enrolment when it is enrolled in tutorial with no stream', tutorial_enrolment_third.errors.full_messages.last
  end

  def test_creating_both_no_stream_and_stream
    unit = FactoryGirl.create(:unit)
    campus = FactoryGirl.create(:campus)
    project = FactoryGirl.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    # Create tutorial with no tutorial stream
    tutorial_first = FactoryGirl.create(:tutorial, unit: unit, campus: campus)
    assert_nil tutorial_first.tutorial_stream

    # Create tutorial with tutorial stream
    tutorial_stream = FactoryGirl.create(:tutorial_stream, unit: unit)
    tutorial_second = FactoryGirl.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: campus)
    assert_not_nil tutorial_second.tutorial_stream

    # Enrol project in tutorial first
    tutorial_enrolment_first = project.enrol_in(tutorial_first)
    assert_equal tutorial_first, tutorial_enrolment_first.tutorial
    assert_equal 1, project.tutorial_enrolments.count

    tutorial_enrolment = FactoryGirl.build(:tutorial_enrolment, project: project)
    tutorial_enrolment.tutorial = tutorial_second
    exception = assert_raises(Exception) { tutorial_enrolment.save! }
    assert_equal 'Validation failed: Project cannot have more than one enrolment when it is enrolled in tutorial with no stream', exception.message
  end

  def test_changing_from_no_stream_to_stream
    unit = FactoryGirl.create(:unit)
    campus = FactoryGirl.create(:campus)
    project = FactoryGirl.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    # Create tutorial with no tutorial stream
    tutorial_first = FactoryGirl.create(:tutorial, unit: unit, campus: campus)
    assert_nil tutorial_first.tutorial_stream

    # Create tutorial with tutorial stream
    tutorial_stream = FactoryGirl.create(:tutorial_stream, unit: unit)
    tutorial_second = FactoryGirl.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: campus)
    assert_not_nil tutorial_second.tutorial_stream

    # Enrol project in tutorial first
    tutorial_enrolment_first = project.enrol_in(tutorial_first)
    assert_equal tutorial_first, tutorial_enrolment_first.tutorial

    # Enrol same project in tutorial second
    tutorial_enrolment_second = project.enrol_in(tutorial_second)
    assert_equal tutorial_second, tutorial_enrolment_second.tutorial

    # Updates rather than creating a new instance
    assert_equal tutorial_enrolment_first.id, tutorial_enrolment_second.id
  end

  def test_changing_from_stream_to_no_stream
    unit = FactoryGirl.create(:unit)
    campus = FactoryGirl.create(:campus)
    project = FactoryGirl.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    # Create tutorial with tutorial stream
    tutorial_stream = FactoryGirl.create(:tutorial_stream, unit: unit)
    tutorial_first = FactoryGirl.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: campus)
    assert_not_nil tutorial_first.tutorial_stream

    # Create tutorial with no tutorial stream
    tutorial_second = FactoryGirl.create(:tutorial, unit: unit, campus: campus)
    assert_nil tutorial_second.tutorial_stream

    # Enrol project in tutorial first
    tutorial_enrolment_first = project.enrol_in(tutorial_first)
    assert_equal tutorial_first, tutorial_enrolment_first.tutorial

    # Enrol same project in tutorial second
    tutorial_enrolment_second = FactoryGirl.build(:tutorial_enrolment, project: project)
    tutorial_enrolment_second.tutorial = tutorial_second
    assert tutorial_enrolment_second.invalid?
    assert_equal 'Project cannot enrol in tutorial with no stream when enrolled in stream', tutorial_enrolment_second.errors.full_messages.last

    exception = assert_raises(Exception) { tutorial_enrolment_second = project.enrol_in(tutorial_second) }
    assert_equal 'Validation failed: Project cannot enrol in tutorial with no stream when enrolled in stream', exception.message
  end

  def test_cannot_enrol_in_tutorial_stream_twice
    unit = FactoryGirl.create(:unit)
    campus = FactoryGirl.create(:campus)
    project = FactoryGirl.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial_stream = FactoryGirl.create(:tutorial_stream, unit: unit)
    tutorial_first = FactoryGirl.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: campus)
    tutorial_second = FactoryGirl.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: campus)

    # Confirm that both tutorials have same tutorial stream
    assert_equal tutorial_stream, tutorial_first.tutorial_stream
    assert_equal tutorial_stream, tutorial_second.tutorial_stream

    # Enrol project in tutorial first
    tutorial_enrolment_first = project.enrol_in(tutorial_first)
    assert_equal tutorial_first, tutorial_enrolment_first.tutorial
    assert_equal project, tutorial_enrolment_first.project

    # Create tutorial enrolment for the second tutorial
    tutorial_enrolment_second = FactoryGirl.build(:tutorial_enrolment, project: project)
    tutorial_enrolment_second.tutorial = tutorial_second
    assert tutorial_enrolment_second.invalid?
    assert_equal 'Project already enrolled in a tutorial with same tutorial stream', tutorial_enrolment_second.errors.full_messages.last
  end

  def test_consistent_campus_is_allowed
    unit = FactoryGirl.create(:unit)
    campus = FactoryGirl.create(:campus)
    project = FactoryGirl.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    # Create tutorial in the same campus
    tutorial = FactoryGirl.create(:tutorial, unit: unit, campus: campus)

    # Make sure campus is same in project and tutorial
    assert_equal project.campus, tutorial.campus

    tutorial_enrolment = project.enrol_in(tutorial)
    assert tutorial_enrolment.valid?
    assert_equal project, tutorial_enrolment.project
    assert_equal tutorial, tutorial_enrolment.tutorial
  end

  def test_campus_inconsistency_raises_error
    unit = FactoryGirl.create(:unit)
    campus_first = FactoryGirl.create(:campus)
    campus_second = FactoryGirl.create(:campus)
    project = FactoryGirl.create(:project, unit: unit, campus: campus_first)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    # Create tutorial in a different campus
    tutorial = FactoryGirl.create(:tutorial, unit: unit, campus: campus_second)

    # Make sure that campus is different in project and tutorial
    assert_not_equal project.campus, tutorial.campus

    tutorial_enrolment = FactoryGirl.build(:tutorial_enrolment, project: project)
    tutorial_enrolment.tutorial = tutorial
    assert tutorial_enrolment.invalid?
    assert_equal 'Project and tutorial belong to different campus', tutorial_enrolment.errors.full_messages.last
  end

  def test_unit_inconsistency_raises_error
    campus = FactoryGirl.create(:campus)
    unit_first = FactoryGirl.create(:unit)
    unit_second = FactoryGirl.create(:unit)

    project = FactoryGirl.create(:project, unit: unit_first, campus: campus)
    tutorial = FactoryGirl.create(:tutorial, unit: unit_second, campus: campus)

    # Make sure that project and tutorial have different units
    assert_not_equal project.unit, tutorial.unit

    tutorial_enrolment = FactoryGirl.build(:tutorial_enrolment, project: project)
    tutorial_enrolment.tutorial = tutorial
    assert tutorial_enrolment.invalid?
    assert_equal 1, tutorial_enrolment.errors.full_messages.count
    assert_equal 'Project and tutorial belong to different unit', tutorial_enrolment.errors.full_messages.last
  end
end
