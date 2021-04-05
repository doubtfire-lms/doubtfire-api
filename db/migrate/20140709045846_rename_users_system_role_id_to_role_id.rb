class RenameUsersSystemRoleIdToRoleId < ActiveRecord::Migration[4.2]
  def change
    rename_column :users, :system_role_id, :role_id
  end
end
