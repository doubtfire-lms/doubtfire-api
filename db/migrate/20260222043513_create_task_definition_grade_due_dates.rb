class CreateTaskDefinitionGradeDueDates < ActiveRecord::Migration[8.0]
  def change
    create_table :task_definition_grade_due_dates do |t|
      t.references :task_definition, null: false
      t.integer :target_grade, null: false
      t.datetime :target_due_date, null: false

      t.timestamps
    end

    add_index :task_definition_grade_due_dates,
              [:task_definition_id, :target_grade],
              unique: true,
              name: "idx_td_grade_due_unique"
  end
end
