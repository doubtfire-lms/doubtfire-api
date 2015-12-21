class AddDueDate < ActiveRecord::Migration
  def change
  	add_column :task_definitions, :due_date, :datetime
  end
end
