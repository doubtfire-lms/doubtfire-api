# frozen_string_literal: true

class CommentReadCursor < ApplicationRecord
  belongs_to :task
  belongs_to :user
  belongs_to :last_read_comment, class_name: 'TaskComment'

  validates :task, :user, :last_read_comment, :read_at, presence: true
  validate :last_read_comment_belongs_to_task

  def self.advance(task:, user:, comment:, read_at: Time.current)
    cursor = create_or_find_by!(task: task, user: user) do |new_cursor|
      new_cursor.last_read_comment = comment
      new_cursor.read_at = read_at
    end

    # A cursor is a high-water mark, so an older comment cannot move it backwards.
    return cursor if cursor.last_read_comment_id >= comment.id

    cursor.with_lock do
      cursor.update!(last_read_comment: comment, read_at: read_at) if cursor.last_read_comment_id < comment.id
    end

    cursor
  end

  private

  def last_read_comment_belongs_to_task
    return if last_read_comment.nil? || last_read_comment.task_id == task_id

    errors.add(:last_read_comment, 'must belong to the same task')
  end
end
