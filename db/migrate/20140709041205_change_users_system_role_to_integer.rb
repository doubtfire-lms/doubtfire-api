class ChangeUsersSystemRoleToInteger < ActiveRecord::Migration
  def change
  	# Change column won't work because a string would need to be cast to an int
  	remove_column 	:users, :system_role
    add_column 		:users, :system_role_id, :integer, default: 0
  end
end
