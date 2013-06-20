class AddRoleToUnitRole < ActiveRecord::Migration
  def up
    add_column :unit_roles, :role_id, :integer
    add_index :unit_roles, :role_id

    student_role = Role.where(name: 'Student').first
    tutor_role = Role.where(name: 'Tutor').first
    convenor_role = Role.where(name: 'Convenor').first

    UnitRole.update_all(role_id: student_role.id)
  end

  def down
    remove_index :unit_roles, :role_id
    remove_column :unit_roles, :role_id
  end
end