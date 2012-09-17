class AddAbbreviationToTaskTemplates < ActiveRecord::Migration
  def change
    add_column :task_templates, :abbreviation, :string
  end
end
