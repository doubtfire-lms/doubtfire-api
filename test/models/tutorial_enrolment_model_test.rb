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
end
