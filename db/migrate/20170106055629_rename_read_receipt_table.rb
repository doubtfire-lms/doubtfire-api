class RenameReadReceiptTable < ActiveRecord::Migration
  def change
    # unique rows
    create_table :comments_read_receipts, id: false do |t|
      t.references :task_comment, index: true, foreign_key: true, null: false
      t.references :user, index: true, foreign_key: true, null: false
      t.timestamps null: false
    end

    add_index :comments_read_receipts, [:task_comment_id, :user_id], unique: true
  end
end
