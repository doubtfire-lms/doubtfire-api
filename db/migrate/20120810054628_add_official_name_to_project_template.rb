class AddOfficialNameToProjectTemplate < ActiveRecord::Migration[4.2]
  def change
    add_column :project_templates, :official_name, :string
  end
end
