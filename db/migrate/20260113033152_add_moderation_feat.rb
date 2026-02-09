class AddModerationFeat < ActiveRecord::Migration[8.0]
  def change
    create_table :tutor_notes do |t|
      t.text :note
      t.references :task, index: true, null: true
      t.references :unit_role, index: true, null: false
      t.references :user, index: true, null: false
      t.references :reply_to, index: true, null: true

      t.boolean :read_by_unit_role, null: false

      t.timestamps
    end

    create_table :tutor_feedback_scores do |t|
      t.references :unit_role, null: false
      t.references :task_definition, null: false
      t.integer :score, default: 50, null: false

      t.timestamps
    end

    create_table :moderated_tasks do |t|
      t.references :task, null: false
      t.references :task_definition, null: false

      t.datetime :last_moderated_date, null: true

      #  open | waiting_for_new_feedback | resolved
      t.string :state, null: false

      # sample | initial_feedback | escalation
      t.string :moderation_type, null: false

      t.bigint :assessor_id, null: true

      # User that dismissed the moderated task
      t.bigint :resolved_by_user_id, null: true
      t.datetime :resolved_at

      # => Moderation
      # - Show me more: state=waiting_for_new_feedback, -score for TaskDefinition
      # - Show me less: state=resolved, outcome=dismissed_good, +score for TaskDefinition
      # - Dismiss:      state=resolved, outcome=dismissed_ok, no score change
      # => Escalation
      # Upheld:         state=resolved, outcome=upheld, -score for TaskDefinition
      # Overturned      state=resolved, outcome=overturned, +score for TaskDefinition
      t.string :outcome, null: true

      t.timestamps
    end

    add_index :moderated_tasks, [:assessor_id, :task_definition_id, :moderation_type],
              name: "idx_mod_tasks_assessor_td_type"

    add_index :moderated_tasks, [:task_id, :moderation_type],
              unique: true,
              name: "uniq_mod_tasks_task_type"

    add_reference :unit_roles, :mentor, index: true
  end
end
