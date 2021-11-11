class AddActiveUntilToTeachingPeriod < ActiveRecord::Migration[4.2]
  def change
    add_column :teaching_periods, :active_until, :datetime, null: false
  end
end
