class AddParentLearningOutcomeToLearningOutcomes < ActiveRecord::Migration[7.1]
  def change
    add_column :learning_outcomes, :parent_learning_outcome_id, :bigint
    add_foreign_key :learning_outcomes, :learning_outcomes, column: :parent_learning_outcome_id
    add_index :learning_outcomes, :parent_learning_outcome_id
  end
end
