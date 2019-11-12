require "test_helper"

class TutorialEnrolmentModelTest < ActiveSupport::TestCase
  def test_default_create
    tutorial_enrolment = FactoryGirl.create(:tutorial_enrolment)
    assert tutorial_enrolment.valid?
  end

  def test_specific_create
    project = FactoryGirl.create(:project)
    tutorial = FactoryGirl.create(:tutorial)
    tutorial_enrolment = FactoryGirl.create(:tutorial_enrolment, project: project, tutorial: tutorial)
    assert_equal tutorial_enrolment.project, project
    assert_equal tutorial_enrolment.tutorial, tutorial
    assert tutorial_enrolment.valid?
  end

  def test_project_plus_tutorial_is_unique
    project = FactoryGirl.create(:project)
    tutorial = FactoryGirl.create(:tutorial)
    tutorial_enrolment = FactoryGirl.create(:tutorial_enrolment, project: project, tutorial: tutorial)
    tutorial_enrolment = FactoryGirl.build(:tutorial_enrolment, project: project, tutorial: tutorial)
    assert tutorial_enrolment.invalid?
  end

  def test_enrol_in_tutorial
    project = FactoryGirl.create(:project)
    tutorial = FactoryGirl.create(:tutorial)
    tutorial_enrolment = project.enrol_in(tutorial)
    assert tutorial_enrolment.valid?
    assert_equal tutorial_enrolment.project, project
    assert_equal tutorial_enrolment.tutorial, tutorial
  end

  def test_enrolling_twice_in_same_tutorial_stream_updates_enrolment
    project = FactoryGirl.create(:project)
    tutorial_stream = FactoryGirl.create(:tutorial_stream)
    tutorial_first = FactoryGirl.create(:tutorial, tutorial_stream: tutorial_stream)
    tutorial_second = FactoryGirl.create(:tutorial, tutorial_stream: tutorial_stream)

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

  def test_changing_from_no_stream_to_stream
    project = FactoryGirl.create(:project)

    # Create tutorial with no tutorial stream
    tutorial_first = FactoryGirl.create(:tutorial)
    assert_nil tutorial_first.tutorial_stream

    # Create tutorial with tutorial stream
    tutorial_stream = FactoryGirl.create(:tutorial_stream)
    tutorial_second = FactoryGirl.create(:tutorial, tutorial_stream: tutorial_stream)
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

  def test_cannot_enrol_in_tutorial_stream_twice
    project = FactoryGirl.create(:project)
    tutorial_first = FactoryGirl.create(:tutorial)
    tutorial_second = FactoryGirl.create(:tutorial, tutorial_stream: tutorial_first.tutorial_stream)

    tutorial_enrolment_first = project.enrol_in(tutorial_first)
    tutorial_enrolment_second = project.enrol_in(tutorial_second)
    assert tutorial_enrolment_first.valid?
    assert tutorial_enrolment_second.valid?
  end
end
