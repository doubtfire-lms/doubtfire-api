class AddUnitDefinitionRefToUnits < ActiveRecord::Migration[7.1]
  def change
    add_reference :units, :unit_definition, null: true, foreign_key: true
  end
end
