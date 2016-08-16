class IncreaseCommentSize < ActiveRecord::Migration
  def change
      change_column :task_comments, :comment, :string, :limit => 4096
      change_column :learning_outcomes, :description, :string, :limit => 4096
      change_column :projects, :grade_rationale, :string, :limit => 4096
      change_column :task_definitions, :upload_requirements, :string, :limit => 4096
      change_column :task_definitions, :plagiarism_checks, :string, :limit => 4096
      change_column :task_definitions, :description, :string, :limit => 4096
      change_column :units, :description, :string, :limit => 4096
  end
end
