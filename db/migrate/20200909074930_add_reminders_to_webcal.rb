class AddRemindersToWebcal < ActiveRecord::Migration
  def change
    add_column :webcals, :reminder_time, :integer
    add_column :webcals, :reminder_unit, :string
  end
end
