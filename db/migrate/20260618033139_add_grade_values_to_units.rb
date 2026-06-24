class AddGradeValuesToUnits < ActiveRecord::Migration[8.0]
  DEFAULT_GRADE_VALUES = [0, 1, 2, 3].to_json

  def up
    add_column :units, :grade_values, :json
    execute "UPDATE units SET grade_values = #{connection.quote(DEFAULT_GRADE_VALUES)}"
    change_column_null :units, :grade_values, false

    change_column_null :task_definition_grade_due_dates, :target_due_date, true
    add_column :task_definition_grade_due_dates, :start_date, :datetime, null: true unless column_exists?(:task_definition_grade_due_dates, :start_date)
  end

  def down
    remove_column :task_definition_grade_due_dates, :start_date if column_exists?(:task_definition_grade_due_dates, :start_date)
    change_column_null :task_definition_grade_due_dates, :target_due_date, false
    remove_column :units, :grade_values
  end
end
