class ChangeTeamMembershipToUnitRole < ActiveRecord::Migration
  def change
    rename_table :team_memberships, :unit_roles
  end
end
