class AddTargetGrade < ActiveRecord::Migration[4.2]
  def change
  	add_column :projects, :target_grade, :integer, :default => 0
  	add_column :task_definitions, :target_grade, :integer, :default => 0
  end
end
