class RenameTaskTemplateIdToTaskDefinitionId < ActiveRecord::Migration
  def change
    rename_column :tasks, :task_template_id, :task_definition_id

    rename_index :tasks, "index_tasks_on_task_template_id", "index_tasks_on_task_definition_id"
    rename_index :task_definitions, "index_task_templates_on_unit_id", "index_task_definitions_on_unit_id"
  end
end
