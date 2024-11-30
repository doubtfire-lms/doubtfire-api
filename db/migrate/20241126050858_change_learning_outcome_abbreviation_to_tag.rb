class ChangeLearningOutcomeAbbreviationToTag < ActiveRecord::Migration[7.1]
  def change
    rename_column :learning_outcomes, :abbreviation, :tag
  end
end
