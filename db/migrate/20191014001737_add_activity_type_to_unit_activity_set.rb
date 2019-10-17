class AddActivityTypeToUnitActivitySet < ActiveRecord::Migration
  def change
    add_reference :unit_activity_sets, :activity_type, null: false, foreign_key: true
  end
end
