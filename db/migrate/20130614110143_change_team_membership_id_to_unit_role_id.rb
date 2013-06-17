class ChangeTeamMembershipIdToUnitRoleId < ActiveRecord::Migration
  def change
    rename_column :projects, :team_membership_id, :unit_role_id

    rename_index :projects, "index_projects_on_team_membership_id", "index_projects_on_unit_role_id"

    rename_index :unit_roles, "index_team_memberships_on_project_id", "index_unit_roles_on_project_id"
    rename_index :unit_roles, "index_team_memberships_on_team_id", "index_unit_roles_on_team_id"
    rename_index :unit_roles, "index_team_memberships_on_user_id", "index_unit_roles_on_user_id"
  end
end
