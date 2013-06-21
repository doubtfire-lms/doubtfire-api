class CreateUserRoles < ActiveRecord::Migration
  def up
    create_table :user_roles do |t|
      t.references :user
      t.references :role

      t.timestamps
    end
    add_index :user_roles, :user_id
    add_index :user_roles, :role_id

    UnitRole.all.each do |unit_role|
      user_role = UserRole.find_or_create_by_user_id_and_role_id(user_id: unit_role.user_id, role_id: unit_role.role_id)
      user_role.save!
    end
  end

  def down
    drop_table :user_roles
  end
end