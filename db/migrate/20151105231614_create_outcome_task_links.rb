class CreateOutcomeTaskLinks < ActiveRecord::Migration
  def change
    create_table :learning_outcome_task_links do |t|
      t.text :description
      t.integer :rating
      t.references :task_definition, index: true
      t.references :task, index: true
      t.references :intended_learning_outcome

      t.timestamps
    end
  end
end
