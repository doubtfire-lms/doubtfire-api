class AddTargetGrade < ActiveRecord::Migration
  def change
  	add_column :projects, :target_grade, :integer, :default => 0
  	add_column :task_definitions, :target_grade, :integer, :default => 0
  end
end
