class CreateOverflowTaskClaimLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :overflow_task_claim_logs do |t|
      t.references :unit, null: false
      t.references :task, null: false
      t.references :claimed_by_unit_role, null: false
      t.references :claimed_by_user, null: false
      t.references :original_tutor_user
      t.references :student_user, null: false
      t.integer :days_awaiting_feedback, null: false
      t.datetime :claimed_at, null: false
      t.timestamps
    end

    add_index :overflow_task_claim_logs, [:unit_id, :claimed_at]
  end
end
