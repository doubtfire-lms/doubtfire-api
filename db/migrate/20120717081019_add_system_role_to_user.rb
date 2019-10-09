class AddSystemRoleToUser < ActiveRecord::Migration[4.2]
	def up
		add_column :users, :system_role, :string
	end

	def down
		remove_column :users, :system_role
	end
end
