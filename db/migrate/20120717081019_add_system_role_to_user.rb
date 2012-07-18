class AddSystemRoleToUser < ActiveRecord::Migration
  
	def up
		add_column :users, :system_role_id, :integer
	end

	def down
		remove_column :users, :system_role_id
	end

end
