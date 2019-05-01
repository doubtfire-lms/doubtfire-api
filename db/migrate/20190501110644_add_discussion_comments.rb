class AddDiscussionComments < ActiveRecord::Migration
  def change
    create_table :discussion_comments do |t|
      t.references :task_comment, index: true
      t.datetime :time_created
      t.datetime :due_date
      t.datetime :time_completed
      t.boolean :started
      t.boolean :completed

      t.timestamps null: false
    end
    add_reference :task_comments, :discussion_comment, index: true, optional: true
  end
end
