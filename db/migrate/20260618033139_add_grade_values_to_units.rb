class AddGradeValuesToUnits < ActiveRecord::Migration[8.0]
  def change
    add_column :units, :grade_values, :json, null: false, default: [0, 1, 2, 3]
  end
end
