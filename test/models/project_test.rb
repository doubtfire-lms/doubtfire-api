require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  def test_campus_inconsistency_raises_error
    campus = FactoryGirl.create(:campus)

    project = Project.create!
    project.tutorial = Tutorial.first
    project.campus = campus
    project.save

    assert project.invalid?
  end

  def test_consistent_campus_is_allowed
    campus = FactoryGirl.create(:campus)
    tutorial = Tutorial.first

    tutorial.campus = campus
    tutorial.save!

    project = Project.create!
    project.tutorial = Tutorial.first
    project.campus = campus
    project.save!

    assert project.valid?
  end
end
