class CreateCourseMap < ActiveRecord::Migration[7.1]
  def change
    create_table :course_maps do |t|
      t.integer :userId
      t.integer :courseId

      t.timestamps
    end
  end
end
