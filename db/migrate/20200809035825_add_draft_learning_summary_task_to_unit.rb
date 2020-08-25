class AddDraftLearningSummaryTaskToUnit < ActiveRecord::Migration
  def change
    add_reference :units, :draft_task_definition, references: :task_definitions
  end
end
