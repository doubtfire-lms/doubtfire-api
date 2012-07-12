class CreateTaskStatuses < ActiveRecord::Migration
  def change
    create_table :task_statuses do |t|	
      t.string :name
      t.string :description

      t.timestamps
    end
  end
end
