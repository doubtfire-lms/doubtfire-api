class RenameTaskTemplateToTaskDefinition < ActiveRecord::Migration[4.2]
  def change
    rename_table :task_templates, :task_definitions
  end
end
