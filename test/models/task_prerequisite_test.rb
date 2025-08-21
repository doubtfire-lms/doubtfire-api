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
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 3)

    td1 = unit.task_definitions.first
    td2 = unit.task_definitions.second
    td3 = unit.task_definitions.third

    assert td1.valid?
    assert td2.valid?
    assert td3.valid?

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
    prereq2.destroy!

    # Ensure that we can still add td1 as prerequisite to another task
    prereq3 = TaskPrerequisite.new(
      task_definition: td3,
      prerequisite: td1
    )

    assert prereq3.valid?
    prereq3.destroy!
    prereq1.destroy!

    # Double check that we can now create the same prerequisite after removing the other one
    prereq = TaskPrerequisite.new(
      task_definition: td2,
      prerequisite: td1
    )
    assert prereq.valid?
  end

  def test_both_task_definitions_belong_to_same_unit
    unit1 = FactoryBot.create(:unit, student_count: 1, task_count: 2)
    unit2 = FactoryBot.create(:unit, student_count: 1, task_count: 2)

    td1 = unit1.task_definitions.first
    td2 = unit2.task_definitions.first

    assert td1.valid?
    assert td2.valid?

    # Test that a TaskPrerequisite cannot be created if the task and its prerequisite belong to different units
    prereq = TaskPrerequisite.new(
      task_definition: td1,
      prerequisite: td2
    )
    assert_not prereq.valid?, "Prerequisite task must be from the same unit"
    prereq.destroy!

    prereq = TaskPrerequisite.new(
      task_definition: td2,
      prerequisite: td1
    )
    assert_not prereq.valid?, "Prerequisite task must be from the same unit"
    prereq.destroy!
  end

  def test_prerequisite_cant_be_higher_target_grade
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 5)

    td1 = unit.task_definitions.first
    td2 = unit.task_definitions.second
    td3 = unit.task_definitions.third
    td4 = unit.task_definitions.fourth
    td5 = unit.task_definitions.fifth

    assert td1.valid?
    assert td2.valid?
    assert td3.valid?
    assert td4.valid?
    assert td5.valid?

    td1.update(target_grade: 3) # HD Task
    td2.update(target_grade: 2) # D Task
    td3.update(target_grade: 1) # C Task
    td4.update(target_grade: 0) # P Task

    td5.update(target_grade: 0) # P Task

    prereq = TaskPrerequisite.new(
      task_definition: td2,
      prerequisite: td1
    )

    assert_not prereq.valid?, "Prerequisite task can not be of a higher target grade"
    prereq.destroy!

    prereq = TaskPrerequisite.new(
      task_definition: td3,
      prerequisite: td2
    )

    assert_not prereq.valid?, "Prerequisite task can not be of a higher target grade"
    prereq.destroy!

    prereq = TaskPrerequisite.new(
      task_definition: td4,
      prerequisite: td3
    )

    assert_not prereq.valid?, "Prerequisite task can not be of a higher target grade"
    prereq.destroy!

    prereq = TaskPrerequisite.new(
      task_definition: td4,
      prerequisite: td1
    )

    assert_not prereq.valid?, "Prerequisite task can not be of a higher target grade"
    prereq.destroy!

    prereq = TaskPrerequisite.new(
      task_definition: td4,
      prerequisite: td2
    )

    assert_not prereq.valid?, "Prerequisite task can not be of a higher target grade"
    prereq.destroy!

    # Both pass tasks
    prereq = TaskPrerequisite.new(
      task_definition: td4,
      prerequisite: td5
    )

    assert prereq.valid?, "Prerequisite task with lower or equal target grade should be valid"
    prereq.destroy!

    prereq = TaskPrerequisite.new(
      task_definition: td1,
      prerequisite: td4
    )

    assert prereq.valid?, "Prerequisite task with lower or equal target grade should be valid"
    prereq.destroy!
  end
end
