class AddActiveToProjectTemplate < ActiveRecord::Migration
  def change
    add_column :project_templates, :active, :boolean, default: true
  end
end
