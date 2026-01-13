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

    create_table :moderated_tasks do |t|
      t.references :task, null: false, foreign_key: true, index: { unique: true }
      t.datetime :last_moderated_date, null: true

      # User that dismissed the moderated task
      t.references :user, null: true
      t.boolean :dismissed, null: false, default: false

      t.timestamps
    end

    add_reference :unit_roles, :mentor, index: true
    add_column :unit_roles, :trust_factor, :integer, default: 50, null: false
  end
end
