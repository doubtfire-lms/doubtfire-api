class AddFlagsToToggleSync < ActiveRecord::Migration
  def change
    add_column :units, :enable_sync_timetable, :boolean, default: true, null: false
    add_column :units, :enable_sync_enrolments, :boolean, default: true, null: false
  end
end
