class AddSystemRoleToUser < ActiveRecord::Migration
	def up
		add_column :users, :system_role, :string
	end

	def down
		remove_column :users, :system_role
	end
end