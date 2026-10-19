class CreateCommentReadCursors < ActiveRecord::Migration[8.0]
  def up
    create_cursor_table
    backfill_cursors
  end

  def down
    drop_table :comment_read_cursors
  end

  private

  def create_cursor_table
    create_table :comment_read_cursors do |t|
      t.references :task, null: false
      t.references :user, null: false
      t.references :last_read_comment, null: false
      t.datetime :read_at, null: false

      t.timestamps
      t.index [:task_id, :user_id], unique: true
    end
  end

  def backfill_cursors
    say_with_time 'Backfilling comment read cursors' do
      execute <<~SQL
        INSERT INTO comment_read_cursors
          (task_id, user_id, last_read_comment_id, read_at, created_at, updated_at)
        SELECT
          task_comments.task_id,
          comments_read_receipts.user_id,
          MAX(comments_read_receipts.task_comment_id),
          MAX(comments_read_receipts.updated_at),
          MIN(comments_read_receipts.created_at),
          MAX(comments_read_receipts.updated_at)
        FROM comments_read_receipts
        INNER JOIN task_comments
          ON task_comments.id = comments_read_receipts.task_comment_id
        GROUP BY task_comments.task_id, comments_read_receipts.user_id
      SQL
    end
  end
end
