class AddGradeValuesToUnits < ActiveRecord::Migration[8.0]
  def change
    add_column :units, :grade_values, :json, null: false, default: [0, 1, 2, 3]

    change_column_null :task_definition_grade_due_dates, :target_due_date, true
    add_column :task_definition_grade_due_dates, :start_date, :datetime, null: true unless column_exists?(:task_definition_grade_due_dates, :start_date)
  end
end
