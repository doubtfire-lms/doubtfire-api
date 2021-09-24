class AddStudentIdToUser < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :student_id, :string, null: true, unique: true
  end
end
