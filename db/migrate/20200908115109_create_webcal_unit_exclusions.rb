class CreateWebcalUnitExclusions < ActiveRecord::Migration
  def change

    create_table :webcal_unit_exclusions do |t|
      t.references :webcal, foreign_key: true, null: false
      t.references :unit, foreign_key: true, null: false
    end

    add_index :webcal_unit_exclusions, [:unit_id, :webcal_id], { unique: true }

  end
end
