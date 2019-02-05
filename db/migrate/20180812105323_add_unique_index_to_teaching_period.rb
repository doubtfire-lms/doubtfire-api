class AddUniqueIndexToTeachingPeriod < ActiveRecord::Migration
  def change
    add_index :teaching_periods, [:period, :year], unique: true
  end
end
