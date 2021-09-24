class AddYearToTeachingPeriods < ActiveRecord::Migration[4.2]
  def change
    add_column :teaching_periods, :year, :integer, null: false
  end
end
