require 'test_helper'

#
# Contains tests for TaskPrerequisite model objects - not accessed via API
#
class TaskDefinitionTest < ActiveSupport::TestCase
  def app
    Rails.application
  end

  def test_task_prerequisite_validation
    # Initialise unit and task definitions
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 2)

    td1 = unit.task_definitions.first
    td2 = unit.task_definitions.second

    assert td1.valid?
    assert td2.valid?

    # Ensure prerequisite cant be the same as the task definition
    prereq = TaskPrerequisite.new(
      task_definition: td1,
      prerequisite: td1
    )

    assert_not prereq.valid?
    assert_includes prereq.errors[:prerequisite], "cannot be the same as the task definition"
    prereq.destroy!

    # Ensure prerequisite 1 is valid
    prereq1 = TaskPrerequisite.create!(
      task_definition: td1,
      prerequisite: td2
    )
    assert prereq1.valid?

    # Ensure that we cant add a reverse prerequisite while prereq1 exists
    # Otherwise, neither task would be able to be submitted
    prereq2 = TaskPrerequisite.new(
      task_definition: td2,
      prerequisite: td1
    )

    assert_not prereq2.valid?
    assert_includes prereq2.errors[:base], "reverse prerequisite already exists"
    prereq1.destroy!
    prereq2.destroy!

    # Double check that we can now create the same prerequisite after removing the other one
    prereq = TaskPrerequisite.new(
      task_definition: td2,
      prerequisite: td1
    )
    assert prereq.valid?
  end
end
