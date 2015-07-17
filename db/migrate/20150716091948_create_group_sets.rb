class CreateGroupSets < ActiveRecord::Migration
  def change
    create_table :group_sets do |t|
      t.references :unit
      t.string :name
      t.boolean :allow_students_to_create_groups, default: true
      t.boolean :allow_students_to_manage_groups, default: true
      t.boolean :keep_groups_in_same_class, default: false

      t.timestamps
    end

    add_index :group_sets, :unit_id
  end
end
