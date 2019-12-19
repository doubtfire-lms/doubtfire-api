class CreateOverseerAssessments < ActiveRecord::Migration
  def change
    create_table :overseer_assessments do |t|
      t.references :task, index: true, foreign_key: true, null: false
      t.string :submission_timestamp, null: false
      t.string :result_task_status
      t.integer :status, null: false, default: 0

      t.timestamps null: false
    end
    add_index :overseer_assessments, [:task_id, :submission_timestamp], unique: true
  end
end
