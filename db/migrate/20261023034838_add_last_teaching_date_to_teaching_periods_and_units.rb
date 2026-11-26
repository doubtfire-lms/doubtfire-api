class AddLastTeachingDateToTeachingPeriodsAndUnits < ActiveRecord::Migration[8.0]
  def up
    add_column :teaching_periods, :last_teaching_date, :date
    add_column :units, :last_teaching_date, :date

    execute 'UPDATE teaching_periods SET last_teaching_date = DATE(end_date)'
    execute 'UPDATE units SET last_teaching_date = DATE(end_date)'

    change_column_null :teaching_periods, :last_teaching_date, false
    change_column_null :units, :last_teaching_date, false
  end

  def down
    remove_column :units, :last_teaching_date
    remove_column :teaching_periods, :last_teaching_date
  end
end
