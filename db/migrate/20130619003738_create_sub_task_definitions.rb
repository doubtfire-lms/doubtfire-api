class CreateSubTaskDefinitions < ActiveRecord::Migration[4.2]
  def change
    create_table :sub_task_definitions do |t|
      t.string :name
      t.text :description
      t.references :badges
      t.references :task_definitions

      t.timestamps
    end
    add_index :sub_task_definitions, :badges_id
  end
end
