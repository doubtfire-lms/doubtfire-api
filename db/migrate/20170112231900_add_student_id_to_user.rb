class AddStudentIdToUser < ActiveRecord::Migration
  def change
    add_column :users, :student_id, :string, null: true, unique: true
  end
end
