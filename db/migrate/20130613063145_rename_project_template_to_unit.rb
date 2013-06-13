class RenameProjectTemplateToUnit < ActiveRecord::Migration
  def change
    rename_table :project_templates, :units
  end
end
