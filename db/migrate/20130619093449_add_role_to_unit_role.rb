class AddRoleToUnitRole < ActiveRecord::Migration
  def up
    add_column :unit_roles, :role_id, :integer
    add_index :unit_roles, :role_id

    remove_index :unit_roles, :project_id
    remove_column :unit_roles, :project_id

    student_role = Role.where(name: 'Student').first
    tutor_role = Role.where(name: 'Tutor').first
    convenor_role = Role.where(name: 'Convenor').first

    add_column :unit_roles, :unit_id, :integer
    add_index :unit_roles, :unit_id

    # Make all existing unit roles (just students at this stage)
    # have the student role
    UnitRole.includes(:project).all.each do |unit_role|
      unit_role.role_id = student_role.id
      unit_role.unit_id = unit_role.project.unit_id
      unit_role.save!
    end

    # Add unit_role_id to Tutorial (to supplant user_id)
    add_column :tutorials, :unit_role_id, :integer
    add_index :tutorials, :unit_role_id

    tutorial_user_map = {}
    tutorial_unit_map = {}
    user_unit_unit_role_map = {}

    # For each tutorial,
    Tutorial.all.each do |tutorial|
      tutor = tutorial.user_id
      unit = tutorial.unit_id
      tutorial_id = tutorial.id

      tutorial_unit_map[tutorial_id] = unit
      tutorial_user_map[tutorial_id] = tutor
    end

    tutorial_user_map.each do |tutorial, user|
      # Skip creating a unit role if there is already one
      # for the given user
      unit = tutorial_unit_map[tutorial]

      if user_unit_unit_role_map[user] && user_unit_unit_role_map[user][unit]
        next # Don't bother creating another role for the user
      else
        unit_role = UnitRole.new(user_id: user, role_id: tutor_role.id, unit_id: unit)
        unit_role.save!

        user_unit_unit_role_map[user] ||= {}
        user_unit_unit_role_map[user][unit] = unit_role.id
      end
    end

    Tutorial.all.each do |tutorial|
      unit = tutorial_unit_map[tutorial.id]
      tutorial.unit_role_id = user_unit_unit_role_map[tutorial_user_map[tutorial.id]][unit]
      tutorial.save!
    end

    remove_index :tutorials, :user_id
    remove_column :tutorials, :user_id
  end

  def down
    # Destroy all non-student unit roles
    execute <<-SQL
      DELETE FROM unit_roles WHERE role_id <> 1
    SQL

    remove_index :unit_roles, :role_id
    remove_column :unit_roles, :role_id
  end
end