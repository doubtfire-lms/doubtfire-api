class ChangeFeedbackChipColumns < ActiveRecord::Migration[7.1]
  def change
    # remove the unuseful columns
    remove_column :feedback_chips, :related_entity, :string
    remove_column :feedback_chips, :section, :string

    # rename the learning_outcome column to learning_outcome_id
    rename_column :feedback_chips, :learning_outcome, :learning_outcome_id
    change_column :feedback_chips, :learning_outcome_id, :bigint, null: false
    add_foreign_key :feedback_chips, :learning_outcomes, column: :learning_outcome_id
  end
end
