class AddDiscussionComments < ActiveRecord::Migration
  def change
    create_table :discussion_comments do |t|
      t.references :task_comment, index: true
      t.datetime :time_started
      t.datetime :time_completed
      t.timestamps null: false
    end
    add_reference :task_comments, :discussion_comment, index: true, optional: true
  end
end
