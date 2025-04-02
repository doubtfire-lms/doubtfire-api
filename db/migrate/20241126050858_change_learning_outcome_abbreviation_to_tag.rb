class ChangeLearningOutcomeAbbreviationToTag < ActiveRecord::Migration[7.1]
  def change
    rename_column :learning_outcomes, :name, :short_description
    rename_column :learning_outcomes, :description, :full_outcome_description

    LearningOutcome.find_each do |learning_outcome|
      learning_outcome.update(abbreviation: "ULO#{learning_outcome.ilo_number}")
    end
  end
end
