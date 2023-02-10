class RefactorReadReceipts < ActiveRecord::Migration[7.0]
  def change
    create_table :last_message_reads do |t|
      t.references :user, null: false, foreign_key: true
      t.references :message, null: false, foreign_key: true
      t.datetime :read_at, null: false
      t.bigint :context_id, null: false
      t.integer :context_type, null: false
    end

    last_crr_query = "
      INSERT INTO last_message_reads (user_id, message_id, read_at, context_id, context_type)
      SELECT comments_read_receipts.user_id, messages.id, MAX(comments_read_receipts.created_at) AS last_date, messages.task_id, 0
      FROM
        comments_read_receipts
        INNER JOIN messages ON `comments_read_receipts`.`task_comment_id` = `messages`.`id`
      GROUP BY
        comments_read_receipts.user_id, messages.task_id"


    result = ActiveRecord::Base.connection.execute(last_crr_query)

    drop_table :comments_read_receipts
  end
end
