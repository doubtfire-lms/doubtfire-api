class CreateTaskComments < ActiveRecord::Migration
  def change
    create_table :task_comments do |t|
			t.references 	:task,        null: false
			t.references	:user,        null: false
      t.string 			:comment,     limit: 2048
      t.datetime    :created_at,  null: false
    end
    add_index :task_comments, :task_id
  end
end
