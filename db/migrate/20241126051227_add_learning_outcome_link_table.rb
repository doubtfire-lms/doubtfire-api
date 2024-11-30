class AddLearningOutcomeLinkTable < ActiveRecord::Migration[7.1]
  def change
    remove_column :learning_outcomes, :parent_learning_outcome_id

    create_table :learning_outcome_links do |t|
      t.references :source, null: false, foreign_key: { to_table: :learning_outcomes }
      t.references :target, null: false, foreign_key: { to_table: :learning_outcomes }
      t.string :link_type, null: true # maybe we can include this to specify the type of link?
      t.timestamps
    end

    add_index :learning_outcome_links, [:source_id, :target_id], unique: true
  end
end
