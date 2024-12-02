class ChangeLearningOutcomeFields < ActiveRecord::Migration[7.1]
  def change
    remove_column :learning_outcomes, :ilo_number, :integer
    remove_column :learning_outcomes, :name, :string
    remove_column :learning_outcomes, :description, :string
    remove_column :learning_outcomes, :tag, :string

    add_column :learning_outcomes, :abbreviation, :string
    add_column :learning_outcomes, :short_description, :string
    add_column :learning_outcomes, :full_outcome_description, :string
  end
end
