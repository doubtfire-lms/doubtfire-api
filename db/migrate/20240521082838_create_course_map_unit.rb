class CreateCourseMapUnit < ActiveRecord::Migration[7.1]
  def change
    create_table :course_map_units do |t|
      t.integer :courseMapId
      t.integer :unitId
      t.integer :yearSlot
      t.integer :teachingPeriodSlot
      t.integer :unitSlot

      t.timestamps
    end
  end
end
