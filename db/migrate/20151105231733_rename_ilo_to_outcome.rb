class RenameIloToOutcome < ActiveRecord::Migration
  def change
  	rename_table :intended_learning_outcomes, :learning_outcomes
  	
  	rename_column :learning_outcome_task_links, :intended_learning_outcome_id, :learning_outcome_id
  	add_index :learning_outcome_task_links, :learning_outcome_id, :name => 'learning_outcome_task_links_lo_index'
  end
end
