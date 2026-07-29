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

    transaction do
      cursors = where(task_id: task_id, user_id: user_ids)

      # rubocop:disable Rails/SkipsModelValidations
      missing_user_ids = user_ids - cursors.pluck(:user_id)

      # Create first-time cursors in one query.
      if missing_user_ids.any?
        insert_all(
          missing_user_ids.map do |user_id|
            {
              task_id: task_id,
              user_id: user_id,
              last_read_comment_id: comment_id,
              read_at: read_at,
              created_at: now,
              updated_at: now
            }
          end
        )
      end

      # Existing cursors only move forward.
      cursors
        .where('last_read_comment_id < ?', comment_id)
        .update_all(
          last_read_comment_id: comment_id,
          read_at: read_at,
          updated_at: now
        )
      # rubocop:enable Rails/SkipsModelValidations
    end
  end

  private

  def last_read_comment_belongs_to_task
    return if last_read_comment.nil? || last_read_comment.task_id == task_id

    errors.add(:last_read_comment, 'must belong to the same task')
  end
end
