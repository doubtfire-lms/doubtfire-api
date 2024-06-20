class AddNameUniqIdx < ActiveRecord::Migration[7.0]
  def change
    add_index :group_sets, [:name, :unit_id], unique: true
    add_index :groups, [:name, :group_set_id], unique: true
    add_index :learning_outcomes, [:abbreviation, :unit_id], unique: true
    add_index :overseer_images, :name, unique: true
    add_index :overseer_images, :tag, unique: true
    add_index :task_definitions, [:abbreviation, :unit_id], unique: true
    add_index :task_definitions, [:name, :unit_id], unique: true
    add_index :tutorials, [:abbreviation, :unit_id], unique: true
    add_index :users, :email, unique: true
    add_index :users, :username, unique: true
    add_index :users, :student_id, unique: true
  end
end
