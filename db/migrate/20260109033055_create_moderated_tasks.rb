class CreateModeratedTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :moderated_tasks do |t|
      t.references :task, null: false, foreign_key: true, index: { unique: true }
      t.datetime :last_moderated_date, null: true

      # User that dismissed the moderated task
      t.references :user, null: true
      t.boolean :dismissed, null: false, default: false

      t.timestamps
    end
  end
end
