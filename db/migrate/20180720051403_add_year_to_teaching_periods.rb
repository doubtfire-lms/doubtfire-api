class AddYearToTeachingPeriods < ActiveRecord::Migration
  def change
    add_column :teaching_periods, :year, :integer, null: false
  end
end
