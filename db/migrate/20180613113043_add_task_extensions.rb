class AddTaskExtensions < ActiveRecord::Migration
  def change
    add_column :tasks, :extensions, :integer, null: false, unique: true, default: 0
  end
end
