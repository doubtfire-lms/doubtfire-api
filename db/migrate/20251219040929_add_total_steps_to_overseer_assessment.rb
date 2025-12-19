class AddTotalStepsToOverseerAssessment < ActiveRecord::Migration[8.0]
  def change
    # Track the number of available steps at the time of assessment
    add_column :overseer_assessments, :total_steps, :integer
  end
end
