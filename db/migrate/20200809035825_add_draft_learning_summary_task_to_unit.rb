class AddDraftLearningSummaryTaskToUnit < ActiveRecord::Migration
  def change
    add_reference :units, :draft_task, references: :task_definitions
  end
end
