class CreateUnitDefinitions < ActiveRecord::Migration[7.1]
  def change
    create_table :unit_definitions do |t|
      t.string :name
      t.string :code
      t.string :description
      t.string :version

      t.timestamps
    end
  end
end
