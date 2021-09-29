class ChangeTeamMembershipToUnitRole < ActiveRecord::Migration[4.2]
  def change
    rename_table :team_memberships, :unit_roles
  end
end
