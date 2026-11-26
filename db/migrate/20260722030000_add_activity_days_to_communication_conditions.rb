class AddActivityDaysToCommunicationConditions < ActiveRecord::Migration[8.0]
  def change
    add_column :communication_conditions, :activity_days, :integer
  end
end
