class AddProjectGrade < ActiveRecord::Migration[4.2]
  def change
  	add_column :projects, :grade, :integer, default: 0
  	add_column :projects, :grade_rationale, :string, limit: 2048
  end
end
