class CreateTaskPrerequisites < ActiveRecord::Migration[8.0]
  def change
    create_table :task_prerequisites do |t|
      t.references :task_definition, null: false
      t.references :prerequisite, null: false
      t.references :task_status, null: false
      t.index [:task_definition_id, :prerequisite_id], unique: true
      t.timestamps
    end
  end
end
