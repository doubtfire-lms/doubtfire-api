class CreateTeamMemberships < ActiveRecord::Migration
  def change
    create_table :team_memberships do |t|
      t.references :user
      t.references :team
      t.references :project

      t.timestamps
    end
    add_index :team_memberships, :user_id
    add_index :team_memberships, :team_id
    add_index :team_memberships, :project_id
  end
end
