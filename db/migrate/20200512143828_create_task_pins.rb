class CreateTaskPins < ActiveRecord::Migration
  def change
    create_table :task_pins do |t|
      t.integer :task_id
      t.integer :user_id

      t.timestamps null: false
    end
  end
end
