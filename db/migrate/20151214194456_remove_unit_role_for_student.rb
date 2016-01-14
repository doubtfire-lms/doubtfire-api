class RemoveUnitRoleForStudent < ActiveRecord::Migration
  def change
  	add_column :projects, :tutorial_id, :integer
  	add_column :projects, :user_id, :integer
  	add_index :projects, [:tutorial_id], name: "index_projects_on_tutorial_id", using: :btree
  	add_index :projects, [:user_id], name: "index_projects_on_user_id", using: :btree

  	if Role.count > 0
  		puts "-- Migrating tutorial from student unit role to project"
	  	UnitRole.where("role_id = :student", student: Role.student.id).each do |ur|
	  		proj = Project.where(unit_role_id: ur.id).first
	  		proj.user_id = ur.user_id
	  		proj.tutorial_id = ur.tutorial_id
	  		proj.save

	  		ur.delete
	  	end
	end

  	remove_column :projects, :unit_role_id, :integer
  end
end
