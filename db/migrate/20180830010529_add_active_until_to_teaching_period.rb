class AddActiveUntilToTeachingPeriod < ActiveRecord::Migration
  def change
    add_column :teaching_periods, :active_until, :datetime, null: false
  end
end
