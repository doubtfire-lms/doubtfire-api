class RenameUsersSystemRoleIdToRoleId < ActiveRecord::Migration
  def change
    rename_column :users, :system_role_id, :role_id
  end
end
