class AddDueDate < ActiveRecord::Migration[4.2]
  def change
  	add_column :task_definitions, :due_date, :datetime
  end
end
