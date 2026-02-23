class AddOverflowMarking < ActiveRecord::Migration[8.0]
  def change
    add_column :unit_roles, :can_mark_overflow_tasks, :boolean, default: false

    add_column :units, :feedback_warning_threshold_days, :integer, default: 5
    add_column :units, :feedback_overflow_threshold_days, :integer, default: 7

    create_table :overflow_task_claims do |t|
      t.references :task, null: false, index: { unique: true }
      t.bigint :claimed_by_unit_role_id, null: false
      # TODO: t.int :times_claimed?
      t.timestamps
    end
  end
end
