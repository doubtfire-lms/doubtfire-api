class RemoveRequiredFromTaskDefs < ActiveRecord::Migration
  def change
  	remove_column :task_definitions, :required
  end
end
