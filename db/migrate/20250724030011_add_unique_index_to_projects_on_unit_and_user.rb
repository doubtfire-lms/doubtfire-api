class AddUniqueIndexToProjectsOnUnitAndUser < ActiveRecord::Migration[8.0]
  def change
    add_index :projects, [:unit_id, :user_id], unique: true
  end
end
