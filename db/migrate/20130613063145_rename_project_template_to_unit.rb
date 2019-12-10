class RenameProjectTemplateToUnit < ActiveRecord::Migration[4.2]
  def change
    rename_table :project_templates, :units
  end
end
