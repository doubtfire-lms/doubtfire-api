class RemoveRequiredFromTaskDefs < ActiveRecord::Migration[4.2]
  def change
  	remove_column :task_definitions, :required
  end
end
