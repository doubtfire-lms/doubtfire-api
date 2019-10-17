class CreateUnitActivitySets < ActiveRecord::Migration
  def change
    create_table :unit_activity_sets do |t|
      t.string      :type,  null: false
      t.timestamps          null: false
    end
    add_reference :unit_activity_sets, :unit, index: true
    add_foreign_key :unit_activity_sets, :units
  end
end
