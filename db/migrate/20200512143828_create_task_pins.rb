class CreateTaskPins < ActiveRecord::Migration
  def change

    create_table :task_pins do |t|
      t.references :task, foreign_key: true, null: false
      t.references :user, foreign_key: true, null: false
      t.timestamps null: false
    end

    add_index :task_pins, [:task_id, :user_id], { unique: true }

  end
end
