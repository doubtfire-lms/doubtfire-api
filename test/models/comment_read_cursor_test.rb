require 'test_helper'

class CommentReadCursorTest < ActiveSupport::TestCase
  def test_comment_reads_use_one_cursor_per_task_and_user
    project = FactoryBot.create(:project)
    task = project.task_for_task_definition(project.unit.task_definitions.first)
    reader = project.student
    author = project.unit.main_convenor_user

    comments = [
      task.add_text_comment(author, 'First'),
      task.add_text_comment(author, 'Second'),
      task.add_text_comment(author, 'Third')
    ]

    task.mark_comments_as_read(reader, comments)

    cursor = CommentReadCursor.find_by!(task: task, user: reader)
    assert_equal comments.last.id, cursor.last_read_comment_id
    assert_equal 1, CommentReadCursor.where(task: task, user: reader).count
    assert(comments.none? { |comment| comment.new_for?(reader) })

    CommentReadCursor.advance(
      task: task,
      user: reader,
      comment: comments.first
    )
    assert_equal comments.last.id, cursor.reload.last_read_comment_id

    comments.second.mark_as_unread(reader)

    assert_not comments.first.new_for?(reader)
    assert comments.second.new_for?(reader)
    assert comments.last.new_for?(reader)
  end

  def test_assigned_tutor_reading_a_comment_removes_other_staff_cursors
    project = FactoryBot.create(:project)
    task = project.task_for_task_definition(project.unit.task_definitions.first)
    assigned_tutor = project.tutor_for(task.task_definition)
    other_staff = FactoryBot.create(:user, :tutor)
    project.unit.employ_staff(other_staff, Role.tutor)
    tutor_comment = task.add_text_comment(assigned_tutor, 'Some feedback')
    tutor_comment.mark_as_read(project.student)
    comment = task.add_text_comment(project.student, 'A question')

    comment.mark_as_read(other_staff)
    assert_equal comment.id, CommentReadCursor.find_by!(task: task, user: other_staff).last_read_comment_id

    comment.mark_as_read(assigned_tutor)

    assert comment.read_by?(assigned_tutor)
    assert_nil CommentReadCursor.find_by(task: task, user: other_staff)
    assert_equal tutor_comment.id, CommentReadCursor.find_by!(task: task, user: project.student).last_read_comment_id
  end

  def test_assigned_tutor_cursor_hides_a_task_from_other_staff_inboxes
    project = FactoryBot.create(:project)
    unit = project.unit
    task_definition = unit.task_definitions.first
    assigned_tutor = FactoryBot.create(:user, :tutor)
    assigned_tutor_role = unit.employ_staff(assigned_tutor, Role.tutor)
    tutorial = FactoryBot.create(
      :tutorial,
      unit: unit,
      campus: project.campus,
      tutorial_stream: task_definition.tutorial_stream,
      unit_role: assigned_tutor_role
    )
    project.enrol_in(tutorial)
    other_staff = FactoryBot.create(:user, :tutor)
    unit.employ_staff(other_staff, Role.tutor)
    task = project.task_for_task_definition(task_definition)
    comment = task.add_text_comment(project.student, 'Please review this')

    assert_includes unit.tasks_for_task_inbox(other_staff).map(&:task_id), task.id

    comment.mark_as_read(other_staff)
    assert_equal comment.id, CommentReadCursor.find_by!(task: task, user: other_staff).last_read_comment_id

    comment.mark_as_read(assigned_tutor)

    assert_nil CommentReadCursor.find_by(task: task, user: other_staff)
    assert_not_includes unit.tasks_for_task_inbox(other_staff).map(&:task_id), task.id
  end

  def test_group_students_have_independent_unread_comment_cursors
    unit = FactoryBot.create(
      :unit,
      group_sets: 1,
      groups: [{ gs: 0, students: 2 }],
      group_tasks: [{ idx: 0, gs: 0 }]
    )
    task_definition = unit.task_definitions.first
    projects = unit.groups.first.projects.to_a
    first_task = projects.first.task_for_task_definition(task_definition)
    second_task = projects.second.task_for_task_definition(task_definition)
    tutor = projects.first.tutor_for(task_definition)

    comment = first_task.add_text_comment(tutor, 'Feedback for the group')
    second_task.reload

    assert comment.new_for?(projects.first.student)
    assert comment.new_for?(projects.second.student)
    assert_equal 1, unread_count(projects.first, task_definition)
    assert_equal 1, unread_count(projects.second, task_definition)

    first_task.mark_comments_as_read(projects.first.student, first_task.all_comments)

    assert_not comment.new_for?(projects.first.student)
    assert comment.new_for?(projects.second.student)
    assert_equal 0, unread_count(projects.first, task_definition)
    assert_equal 1, unread_count(projects.second, task_definition)
  end

  def test_destroying_the_cursor_comment_rewinds_each_users_cursor
    project = FactoryBot.create(:project)
    task = project.task_for_task_definition(project.unit.task_definitions.first)
    other_staff = FactoryBot.create(:user, :tutor)
    project.unit.employ_staff(other_staff, Role.tutor)
    author = project.student
    readers = [project.tutor_for(task.task_definition), other_staff]
    previous_comment = task.add_text_comment(author, 'First')
    cursor_comment = task.add_text_comment(author, 'Second')

    readers.each { |reader| cursor_comment.mark_as_read(reader) }

    cursor_comment.destroy!

    readers.each do |reader|
      cursor = CommentReadCursor.find_by!(task: task, user: reader)
      assert_equal previous_comment.id, cursor.last_read_comment_id
    end
  end

  def test_destroying_the_only_comment_removes_its_cursors
    project = FactoryBot.create(:project)
    task = project.task_for_task_definition(project.unit.task_definitions.first)
    reader = project.student
    comment = task.add_text_comment(project.unit.main_convenor_user, 'Only comment')

    comment.mark_as_read(reader)
    comment.destroy!

    assert_nil CommentReadCursor.find_by(task: task, user: reader)
  end

  def test_only_staff_attention_comments_count_in_the_tutor_inbox
    project = FactoryBot.create(:project)
    task = project.task_for_task_definition(project.unit.task_definitions.first)
    tutor = project.tutor_for(task.task_definition)

    student_comment = task.add_text_comment(project.student, 'Please review this')
    status_comment = task.add_status_comment(project.student, TaskStatus.ready_for_feedback)
    assessment_comment = AssessmentComment.create!(
      task: task,
      user: tutor,
      recipient: project.student,
      comment: 'Automated assessment complete'
    )

    assert student_comment.attention_staff?
    assert status_comment.attention_none?
    assert assessment_comment.attention_student?
    assert student_comment.new_for?(tutor)
    assert_not status_comment.new_for?(tutor)
    assert_not assessment_comment.new_for?(tutor)
    assert_nil CommentReadCursor.find_by(task: task, user: tutor)

    inbox_task = project.unit.tasks_for_task_inbox(tutor).find { |item| item.task_id == task.id }
    assert_not_nil inbox_task
    assert_equal 1, inbox_task.number_unread.to_i

    task.mark_comments_as_read(tutor, task.comments)

    cursor = CommentReadCursor.find_by!(task: task, user: tutor)
    assert_equal student_comment.id, cursor.last_read_comment_id
    assert_not(project.unit.tasks_for_task_inbox(tutor).any? { |item| item.task_id == task.id })
  end

  private

  def unread_count(project, task_definition)
    project.task_details_for_shallow_serializer(project.student)
           .find { |task| task[:task_definition_id] == task_definition.id }[:num_new_comments].to_i
  end
end
