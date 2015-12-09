class CreateIntendedLearningOutcomes < ActiveRecord::Migration
  def change
    create_table :intended_learning_outcomes do |t|
      t.references :unit
      t.integer :ilo_number
      t.string :name
      t.string :description
    end
    add_index :intended_learning_outcomes, :unit_id
    end
end
