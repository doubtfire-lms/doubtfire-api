class RemoveProjectConvenorInFavourOfUnitRole < ActiveRecord::Migration
  def up
    convenor_role = Role.where(name: 'Convenor').first
    ProjectConvenor.all.each do |convenor|
      UnitRole.create(unit_id: convenor.unit.id, user_id: convenor.user.id, role_id: convenor_role.id)
    end

    drop_table :project_convenors
  end

  def down
    # Recreate project_convenors
    create_table :project_convenors do |t|
      t.references :unit
      t.references :user

      t.timestamps
    end

    # Get all convenor roles
    convenor_roles = UnitRole.where(role_id: Role.where(name: 'Convenor').first)

    # Recreate ProjectConvenor objects for all convenors
    convenor_roles.each do |convenor_role|
      convenor = convenor_role.user
      unit = convenor_role.unit

      ProjectConvenor.create(unit_id: unit.id, user_id: convenor.id)
    end

    # Destroy convenor roles
    convenor_roles.destroy_all
  end
end
