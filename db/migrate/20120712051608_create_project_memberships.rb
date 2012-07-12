class CreateProjectMemberships < ActiveRecord::Migration
  def change
    create_table :project_memberships do |t|
      t.references :team
      t.references :project_status
      t.references :project
      t.string :project_role

      t.timestamps
    end
    add_index :project_memberships, :team_id
    add_index :project_memberships, :project_status_id
    add_index :project_memberships, :project_id
  end
end
