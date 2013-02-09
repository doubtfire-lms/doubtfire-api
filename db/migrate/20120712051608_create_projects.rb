class CreateProjects < ActiveRecord::Migration
  def change
    create_table :projects do |t|
      t.references :project_template
      t.references :team_membership
      t.string :project_role

      t.timestamps
    end
    add_index :projects, :project_template_id
    add_index :projects, :team_membership_id
  end
end
