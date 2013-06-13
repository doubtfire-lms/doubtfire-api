class RenameTaskTemplateToTaskDefinition < ActiveRecord::Migration
  def change
    rename_table :task_templates, :task_definitions
  end
end
