class AddOfficialNameToProjectTemplate < ActiveRecord::Migration
  def change
    add_column :project_templates, :official_name, :string
  end
end
