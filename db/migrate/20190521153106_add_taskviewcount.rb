class AddTaskviewcount < ActiveRecord::Migration
  def change
    add_column :tasks, :viewcount, :integer, null: false, unique: true, default: 0
  end
end
