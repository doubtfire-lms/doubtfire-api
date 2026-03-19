class AddTargetGradeStartDates < ActiveRecord::Migration[8.0]
  def change
    add_column :task_definition_grade_due_dates, :start_date, :datetime, null: true

    change_column_null :task_definition_grade_due_dates, :target_due_date, true
  end
end
