class AddD2l < ActiveRecord::Migration[7.1]
  def change
    # Create a table linked to the units table,
    # that captures the org unit id, and the grade object id for D2L
    create_table :d2l_assessment_mappings do |t|
      t.references :unit, null: false, foreign_key: true
      t.string :org_unit_id
      t.string :grade_object_id
      t.timestamps
    end
  end
end
