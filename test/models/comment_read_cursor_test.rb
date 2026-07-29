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

  def test_assigned_tutor_reading_a_comment_advances_all_staff_cursors
    project = FactoryBot.create(:project)
    task = project.task_for_task_definition(project.unit.task_definitions.first)
    assigned_tutor = project.tutor_for(task.task_definition)
    other_staff = FactoryBot.create(:user, :tutor)
    project.unit.employ_staff(other_staff, Role.tutor)
    comment = task.add_text_comment(project.student, 'A question')

    comment.mark_as_read(assigned_tutor)

    assert comment.read_by?(assigned_tutor)
    assert comment.read_by?(other_staff)
    assert_equal comment.id, CommentReadCursor.find_by!(task: task, user: other_staff).last_read_comment_id
  end

  def test_changing_tutorial_does_not_show_comments_already_read_by_the_teaching_team
    project = FactoryBot.create(:project)
    unit = project.unit
    task_definition = unit.task_definitions.first
    original_tutor = unit.main_convenor_user
    new_tutor = FactoryBot.create(:user, :tutor)
    new_tutor_role = unit.employ_staff(new_tutor, Role.tutor)
    original_tutorial = FactoryBot.create(
      :tutorial,
      unit: unit,
      campus: project.campus,
      unit_role: unit.unit_role_for(original_tutor)
    )
    new_tutorial = FactoryBot.create(
      :tutorial,
      unit: unit,
      campus: project.campus,
      unit_role: new_tutor_role
    )
    project.enrol_in(original_tutorial)
    task = project.task_for_task_definition(task_definition)
    comment = task.add_text_comment(project.student, 'Please review this')

    original_inbox = unit.tasks_for_task_inbox(original_tutor, true).map(&:task_id)
    assert_includes original_inbox, task.id

    comment.mark_as_read(original_tutor)
    assert_equal comment.id, CommentReadCursor.find_by!(task: task, user: new_tutor).last_read_comment_id

    project.enrol_in(new_tutorial)

    new_tutor_inbox = unit.tasks_for_task_inbox(new_tutor, true).map(&:task_id)
    assert_not_includes new_tutor_inbox, task.id
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
end
