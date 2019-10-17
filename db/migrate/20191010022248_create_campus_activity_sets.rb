class CreateCampusActivitySets < ActiveRecord::Migration
  def change
    create_table :campus_activity_sets do |t|
      t.timestamps null: false
    end
    add_reference :campus_activity_sets, :campus, null: false, foreign_key: true
    add_reference :campus_activity_sets, :unit_activity_set, null: false, foreign_key: true
  end
end
