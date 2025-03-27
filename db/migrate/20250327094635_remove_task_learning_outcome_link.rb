class RemoveTaskLearningOutcomeLink < ActiveRecord::Migration[7.1]
  def up
    drop_table :learning_outcome_task_links
  end
end
