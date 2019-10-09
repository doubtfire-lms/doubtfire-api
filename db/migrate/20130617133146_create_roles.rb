class CreateRoles < ActiveRecord::Migration[4.2]
  def up
    create_table :roles do |t|
      t.string :name
      t.string :description

      t.timestamps
    end

    Role.create name: "Student", description: "Student"
    Role.create name: "Tutor", description: "Student"
    Role.create name: "Convenor", description: "Student"
    Role.create name: "Moderator", description: "Student"
  end

  def down
    drop_table :roles
  end
end
