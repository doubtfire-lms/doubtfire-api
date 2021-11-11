class AddAbbreviationToTaskTemplates < ActiveRecord::Migration[4.2]
  def change
    add_column :task_templates, :abbreviation, :string
  end
end
