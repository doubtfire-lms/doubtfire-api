# frozen_string_literal: true

require 'test_helper'

class ExecuteCommunicationSetJobTest < ActiveSupport::TestCase
  def test_email_student_action_creates_a_notification_with_the_rendered_email
    unit = FactoryBot.create(
      :unit,
      student_count: 1,
      unenrolled_student_count: 0,
      part_enrolled_student_count: 0,
      inactive_student_count: 0,
      task_count: 0
    )
    project = unit.active_projects.first
    student = project.student
    communication_set = unit.communication_sets.create!(name: 'Student email set', active: true)
    rule = communication_set.communication_rules.create!(name: 'Welcome', operator: 'and', position: 0)
    rule.communication_actions.create!(
      type: 'EmailStudentAction',
      subject: 'Hello {{student.first_name}}',
      body: "Welcome to {{unit.code}}.\nThis is your full message."
    )

    assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
      ExecuteCommunicationSetJob.new.perform(communication_set.id)
    end

    notification = Notification.find_by!(recipient: student, project: project, kind: 'communication_email')
    assert_equal "Hello #{student.first_name}", notification.message_subject
    assert_equal "Welcome to #{unit.code}.\nThis is your full message.", notification.message_body
    assert_nil notification.read_at
    assert_not_nil notification.email_processed_at
  end

  def test_email_staff_action_creates_a_notification_for_the_staff_recipient
    unit = FactoryBot.create(
      :unit,
      student_count: 1,
      unenrolled_student_count: 0,
      part_enrolled_student_count: 0,
      inactive_student_count: 0,
      task_count: 1
    )
    project = unit.active_projects.first
    tutor = project.tutor_for(unit.task_definitions.first)
    communication_set = unit.communication_sets.create!(name: 'Staff email set', active: true)
    rule = communication_set.communication_rules.create!(name: 'Follow up', operator: 'and', position: 0)
    rule.communication_actions.create!(
      type: 'EmailStaffAction',
      subject: 'Follow up with {{student.full_name}}',
      body: 'Please contact {{student.username}}.',
      email_tutors: true,
      email_convenors: false
    )

    assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
      ExecuteCommunicationSetJob.new.perform(communication_set.id)
    end

    notification = Notification.find_by!(recipient: tutor, project: project, kind: 'communication_email')
    assert_equal "Follow up with #{project.student.name}", notification.message_subject
    assert_equal "Please contact #{project.student.username}.", notification.message_body
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
    assert_equal "Please review Ada for #{unit.code}", comment_one.comment
    assert_equal "Please review Grace for #{unit.code}", comment_two.comment
  end
end
