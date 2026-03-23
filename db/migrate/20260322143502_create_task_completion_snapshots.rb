# frozen_string_literal: true

class CreateTaskCompletionSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :task_completion_snapshots do |t|
      t.references :unit, null: false, foreign_key: true
      t.date :snapshot_date, null: false
      t.datetime :captured_at, null: false
      t.json :stats, null: false

      t.timestamps
    end

    add_index :task_completion_snapshots, [:unit_id, :snapshot_date], unique: true
    add_index :task_completion_snapshots, :captured_at
  end
end