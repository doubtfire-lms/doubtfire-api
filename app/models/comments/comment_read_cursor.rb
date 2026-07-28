# frozen_string_literal: true

class CommentReadCursor < ApplicationRecord
  belongs_to :task
  belongs_to :user
  belongs_to :last_read_comment, class_name: 'TaskComment'

  validates :task, :user, :last_read_comment, :read_at, presence: true
  validates :task_id, uniqueness: { scope: :user_id }
  validate :last_read_comment_belongs_to_task

  def self.advance(task_id:, user_ids:, comment_id:, read_at: Time.current)
    user_ids = Array(user_ids).compact.map(&:to_i).uniq
    return if user_ids.empty?

    now = Time.current
    values = user_ids.map do |user_id|
      [
        task_id,
        user_id,
        comment_id,
        read_at,
        now,
        now
      ].map { |value| connection.quote(value) }.join(', ')
    end.join('), (')

    connection.execute(<<~SQL.squish)
      INSERT INTO comment_read_cursors
        (task_id, user_id, last_read_comment_id, read_at, created_at, updated_at)
      VALUES (#{values})
      ON DUPLICATE KEY UPDATE
        read_at = IF(
          last_read_comment_id < VALUES(last_read_comment_id),
          VALUES(read_at),
          read_at
        ),
        updated_at = IF(
          last_read_comment_id < VALUES(last_read_comment_id),
          VALUES(updated_at),
          updated_at
        ),
        last_read_comment_id = GREATEST(
          last_read_comment_id,
          VALUES(last_read_comment_id)
        )
    SQL
  end

  private

  def last_read_comment_belongs_to_task
    return if last_read_comment.nil? || last_read_comment.task_id == task_id

    errors.add(:last_read_comment, 'must belong to the same task')
  end
end
