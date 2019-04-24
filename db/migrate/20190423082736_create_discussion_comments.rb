class CreateDiscussionComments < ActiveRecord::Migration
  def change
    create_table :discussion_comments, id: false do |t|
      t.references :task_comment, index: true, foreign_key: true, null: false
      t.references :user, index: true, foreign_key: true, null: false
      t.datetime :time_created
      t.datetime :due_date
      t.datetime :time_completed
      t.bool :started
      t.bool :completed

      t.timestamps null: false
    end
    add_index :discussion_comments, [:task_comment_id, :user_id], unique: true
  end
end
