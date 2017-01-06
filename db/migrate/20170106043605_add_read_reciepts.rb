class AddReadReciepts < ActiveRecord::Migration
  def change
    remove_column :task_comments, :is_new

    create_table :task_comments_read, options: 'id: false' do |t|
      t.references :comments, index: true, foreign_key: true, null: false
      t.references :users, index: true, foreign_key: true, null: false
      t.timestamps null: false
    end
  end
end
