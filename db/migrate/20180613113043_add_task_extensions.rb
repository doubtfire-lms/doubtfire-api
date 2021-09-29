class AddTaskExtensions < ActiveRecord::Migration[4.2]
  def change
    add_column :tasks, :extensions, :integer, null: false, unique: true, default: 0
  end
end
