class AddUniqueIndexToEnrolments < ActiveRecord::Migration
  def change
    add_index :enrolments, [:tutorial_id, :project_id], unique: true
  end
end
