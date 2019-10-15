require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  def get_campus
    data = {
      name: 'Melbourne',
      mode: 'automatic',
      abbreviation: 'Melb'
    }

    Campus.create!(data)
  end

  def test_campus_inconsistency_raises_error
    campus = get_campus

    project = Project.create!
    project.tutorial = Tutorial.first
    project.campus = campus
    project.save

    assert project.invalid?
  end

  def test_consistent_campus_is_allowed
    campus = get_campus
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
