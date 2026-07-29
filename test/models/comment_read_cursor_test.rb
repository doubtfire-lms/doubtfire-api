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

  def test_reading_a_comment_only_advances_the_readers_cursor
    project = FactoryBot.create(:project)
    task = project.task_for_task_definition(project.unit.task_definitions.first)
    assigned_tutor = project.tutor_for(task.task_definition)
    other_staff = FactoryBot.create(:user, :tutor)
    project.unit.employ_staff(other_staff, Role.tutor)
    comment = task.add_text_comment(project.student, 'A question')

    comment.mark_as_read(assigned_tutor)

    assert comment.read_by?(assigned_tutor)
    assert_not comment.read_by?(other_staff)
    assert_nil CommentReadCursor.find_by(task: task, user: other_staff)
  end
end
