class CreateRequirementSet < ActiveRecord::Migration[7.1]
  def change
    create_table :requirement_sets do |t|
      t.integer :requirementSetGroupId
      t.string :description
      t.integer :unitId
      t.integer :requirementId

      t.timestamps
    end
  end
end
