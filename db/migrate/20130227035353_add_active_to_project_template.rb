class AddActiveToProjectTemplate < ActiveRecord::Migration[4.2]
  def change
    add_column :project_templates, :active, :boolean, default: true
  end
end
