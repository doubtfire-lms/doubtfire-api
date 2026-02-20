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

    td1.update(target_grade: 1, target_date: Time.zone.today + 1.week)
    td2.update(target_grade: 1, target_date: Time.zone.today + 1.week)
    td3.update(target_grade: 1, target_date: Time.zone.today + 1.week)
    td1.reload
    td2.reload
    td3.reload

    # Ensure prerequisite cant be the same as the task definition
    prereq = TaskPrerequisite.new(
      task_definition: td1,
      prerequisite: td1,
      task_status_id: TaskStatus.complete.id
    )

    assert_not prereq.valid?
    assert_includes prereq.errors[:prerequisite], "cannot be the same as the task definition"
    prereq.destroy!

    # Ensure prerequisite 1 is valid
    prereq1 = TaskPrerequisite.new(
      task_definition: td1,
      prerequisite: td2,
      task_status_id: TaskStatus.complete.id
    )
    assert prereq1.valid?, prereq1.errors.full_messages

    prereq1.save!

    # Ensure that we cant add a reverse prerequisite while prereq1 exists
    # Otherwise, neither task would be able to be submitted
    prereq2 = TaskPrerequisite.new(
      task_definition: td2,
      prerequisite: td1,
      task_status_id: TaskStatus.complete.id
    )

    assert_not prereq2.valid?, "Reverse task prerequisite should not be valid"

    assert_includes prereq2.errors[:base], "reverse prerequisite already exists"
    prereq2.destroy!

    # Ensure that we can still add td1 as prerequisite to another task
    prereq3 = TaskPrerequisite.new(
      task_definition: td3,
      prerequisite: td1,
      task_status_id: TaskStatus.complete.id
    )

    assert prereq3.valid?, prereq3.errors.full_messages
    prereq3.destroy!
    prereq1.destroy!

    # Double check that we can now create the same prerequisite after removing the other one
    prereq = TaskPrerequisite.new(
      task_definition: td2,
      prerequisite: td1,
      task_status_id: TaskStatus.complete.id
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
      prerequisite: td2,
      task_status_id: TaskStatus.complete.id
    )
    assert_not prereq.valid?, "Prerequisite task must be from the same unit"
    prereq.destroy!

    prereq = TaskPrerequisite.new(
      task_definition: td2,
      prerequisite: td1,
      task_status_id: TaskStatus.complete.id
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

    td1.update(target_grade: 3, target_date: Time.zone.today + 1.week) # HD Task
    td2.update(target_grade: 2, target_date: Time.zone.today + 1.week) # D Task
    td3.update(target_grade: 1, target_date: Time.zone.today + 1.week) # C Task
    td4.update(target_grade: 0, target_date: Time.zone.today + 1.week) # P Task

    td5.update(target_grade: 0, target_date: Time.zone.today + 1.week) # P Task

    prereq = TaskPrerequisite.new(
      task_definition: td2,
      prerequisite: td1,
      task_status_id: TaskStatus.complete.id
    )

    assert_not prereq.valid?, "Prerequisite task can not be of a higher target grade"
    prereq.destroy!

    prereq = TaskPrerequisite.new(
      task_definition: td3,
      prerequisite: td2,
      task_status_id: TaskStatus.complete.id
    )

    assert_not prereq.valid?, "Prerequisite task can not be of a higher target grade"
    prereq.destroy!

    prereq = TaskPrerequisite.new(
      task_definition: td4,
      prerequisite: td3,
      task_status_id: TaskStatus.complete.id
    )

    assert_not prereq.valid?, "Prerequisite task can not be of a higher target grade"
    prereq.destroy!

    prereq = TaskPrerequisite.new(
      task_definition: td4,
      prerequisite: td1,
      task_status_id: TaskStatus.complete.id
    )

    assert_not prereq.valid?, "Prerequisite task can not be of a higher target grade"
    prereq.destroy!

    prereq = TaskPrerequisite.new(
      task_definition: td4,
      prerequisite: td2,
      task_status_id: TaskStatus.complete.id
    )

    assert_not prereq.valid?, "Prerequisite task can not be of a higher target grade"
    prereq.destroy!

    # Both pass tasks
    prereq = TaskPrerequisite.new(
      task_definition: td4,
      prerequisite: td5,
      task_status_id: TaskStatus.complete.id
    )

    assert prereq.valid?, prereq.errors.full_messages
    prereq.destroy!

    prereq = TaskPrerequisite.new(
      task_definition: td1,
      prerequisite: td4,
      task_status_id: TaskStatus.complete.id
    )

    assert prereq.valid?, "Prerequisite task with lower or equal target grade should be valid"
    prereq.destroy!

    assert td2.update(target_grade: 2) # Distinction Task
    assert td3.update(target_grade: 1) # Credit Task

    prereq = TaskPrerequisite.new(
      task_definition: td2,
      prerequisite: td3,
      task_status_id: TaskStatus.complete.id
    )
    prereq.save!

    # Ensure we cant update the Credit task to High Distinction when its a prerequisite TO a higher grade
    # (Would mean you can't complete a Distinction task until the High Disinction task is completed)
    td3.target_grade = 3 # HD
    assert_not td3.valid?
    assert_includes td3.errors[:target_grade].join, "cannot exceed"

    # Ensure we cant update a Distinction task to Pass task when it has a prequisite OF a higher grade
    # (The reverse, would mean you can't complete this pass task until the Disinction task is completed)
    td2.target_grade = 0 # Pass
    assert_not td2.valid?
    assert_includes td2.errors[:target_grade].join, "cannot be lower"
  end

  # def test_due_date_not_before_prerequisite
  #   unit = FactoryBot.create(:unit, student_count: 1, task_count: 5)

  #   td1 = unit.task_definitions.first
  #   td2 = unit.task_definitions.second
  #   td3 = unit.task_definitions.third

  #   assert td1.valid?
  #   assert td2.valid?
  #   assert td3.valid?

  #   # Test 1
  #   td1.update(target_grade: 0, due_date: Time.zone.today + 1.week, target_date: Time.zone.today + 1.week)
  #   td2.update(target_grade: 0, due_date: Time.zone.today - 1.week, target_date: Time.zone.today - 1.week)
  #   td1.reload
  #   td2.reload

  #   prereq = TaskPrerequisite.new(
  #     task_definition: td1,
  #     prerequisite: td2,
  #     task_status_id: TaskStatus.complete.id
  #   )

  #   # Ensure prerequisite with earlier due date is valid
  #   assert prereq.valid?, "Prerequisite with earlier due date than task definition should be valid"
  #   prereq.destroy!

  #   # Test 2
  #   td1.update(target_grade: 0, due_date: Time.zone.today - 1.week, target_date: Time.zone.today - 1.week)
  #   td2.update(target_grade: 0, due_date: Time.zone.today + 1.week, target_date: Time.zone.today + 1.week)
  #   td1.reload
  #   td2.reload

  #   prereq = TaskPrerequisite.new(
  #     task_definition: td1,
  #     prerequisite: td2,
  #     task_status_id: TaskStatus.complete.id
  #   )

  #   # Ensure prerequisite with later due date can not be created
  #   assert_not prereq.valid?, "Prerequisite with a later due date than task definition should not be valid"
  # end
end
