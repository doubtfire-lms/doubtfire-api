class AddTaskStartDate < ActiveRecord::Migration
  def change
    add_column :task_definitions, :start_date, :datetime

    TaskDefinition.all.each do |td|
      td.start_date = td.target_date - 1.weeks
      td.save
    end

    change_column_null :task_definitions, :start_date, false
    change_column_null :task_definitions, :target_date, false
  end
end
