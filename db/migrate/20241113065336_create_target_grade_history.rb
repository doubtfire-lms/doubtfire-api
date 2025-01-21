class CreateTargetGradeHistory < ActiveRecord::Migration[7.1]
  def change
    create_table :target_grade_histories do |t|
      t.integer :project_id, null: false #reference to the unit project
      t.integer :user_id, null: false #This is where we refer to the student by the ID
      t.string :previous_grade #Previous grade of the user before we update it
      t.string :new_grade #Updated grade
      t.integer :changed_by_id #Referene to the user who changed the grade
      t.datetime :changed_at, null: false #The date time when the grade was changed

      t.timestamps
    end
  end
end
