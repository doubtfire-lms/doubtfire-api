class AddUniqueIndexToTeachingPeriod < ActiveRecord::Migration[4.2]
  def change
    add_index :teaching_periods, [:period, :year], unique: true
  end
end
