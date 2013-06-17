class RenameTeamToTutorial < ActiveRecord::Migration
  def change
    rename_table :teams, :tutorials

    rename_column :unit_roles, :team_id, :tutorial_id

    rename_index :tutorials, "index_teams_on_unit_id", "index_tutorials_on_unit_id"
    rename_index :tutorials, "index_teams_on_user_id", "index_tutorials_on_user_id"

    rename_index :unit_roles, "index_unit_roles_on_team_id", "index_unit_roles_on_tutorial_id"
  end
end
