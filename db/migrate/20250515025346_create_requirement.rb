class CreateRequirement < ActiveRecord::Migration[7.1]
  def change
    create_table :requirements do |t|
      t.integer :unitId
      t.integer :courseId
      t.string :type
      t.string :category
      t.string :description
      t.integer :minimum
      t.integer :maximum
      t.integer :requirementSetGroupId

      t.timestamps
    end
  end
end
