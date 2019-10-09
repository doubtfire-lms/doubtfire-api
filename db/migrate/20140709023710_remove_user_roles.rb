class RemoveUserRoles < ActiveRecord::Migration[4.2]
  def change
  	drop_table :user_roles
  end
end
