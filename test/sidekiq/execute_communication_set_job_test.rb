# frozen_string_literal: true

require 'test_helper'

class ExecuteCommunicationSetJobTest < ActiveSupport::TestCase
  def test_task_comment_action_skips_a_frozen_project_without_creating_a_task
    unit = FactoryBot.create(
      :unit,
      with_students: false,
      task_count: 1,
      stream_count: 0,
      tutorials: 0,
      outcome_count: 0,
      staff_count: 1,
      lock_project_on_portfolio_submission: true
    )
    task_definition = unit.task_definitions.first
    project = unit.enrol_student(FactoryBot.create(:user, :student), Campus.first)
    project.update!(compile_portfolio: true)
    communication_set = unit.communication_sets.create!(name: 'Frozen Set', active: true)
    communication_rule = communication_set.communication_rules.create!(
      name: 'Frozen Comment Rule',
      operator: 'and',
      position: 0
    )
    communication_rule.communication_actions.create!(
      type: 'TaskCommentAction',
      task_definition: task_definition,
      body: 'This must not change frozen evidence'
    )

    ExecuteCommunicationSetJob.new.perform(communication_set.id)

    assert_not project.tasks.exists?(task_definition: task_definition)
    assert_empty TaskComment.joins(task: :project).where(projects: { id: project.id })
  end

  def test_task_comment_action_adds_a_comment_to_each_selected_students_task
    unit = FactoryBot.create(
      :unit,
      with_students: false,
      task_count: 1,
      stream_count: 0,
      tutorials: 0,
      outcome_count: 0,
      staff_count: 1
    )

    task_definition = unit.task_definitions.first
    campus = Campus.first
    comment_author = unit.main_convenor_user

    student_one = FactoryBot.create(:user, :student)
    student_one.update!(first_name: 'Ada', last_name: 'Lovelace')
    project_one = unit.enrol_student(student_one, campus)

    student_two = FactoryBot.create(:user, :student)
    student_two.update!(first_name: 'Grace', last_name: 'Hopper')
    project_two = unit.enrol_student(student_two, campus)

    communication_set = unit.communication_sets.create!(name: 'Test Set', active: true)
    communication_rule = communication_set.communication_rules.create!(
      name: 'Comment Rule',
      operator: 'and',
      position: 0
    )
    communication_rule.communication_actions.create!(
      type: 'TaskCommentAction',
      task_definition: task_definition,
      body: 'Please review {{student.first_name}} for {{unit.code}}'
    )

    ExecuteCommunicationSetJob.new.perform(communication_set.id)

    task_one = project_one.task_for_task_definition(task_definition)
    task_two = project_two.task_for_task_definition(task_definition)

    assert_equal 1, TaskComment.where(task: task_one).count
    assert_equal 1, TaskComment.where(task: task_two).count

    comment_one = task_one.comments.last
    comment_two = task_two.comments.last

    assert_equal comment_author, comment_one.user
    assert_equal comment_author, comment_two.user
    assert_equal 'Please review Ada for ' + unit.code, comment_one.comment
    assert_equal 'Please review Grace for ' + unit.code, comment_two.comment
  end
end
