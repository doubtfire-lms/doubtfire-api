class CreateTaskCompletionSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :task_completion_snapshots do |t|
      t.references :unit, null: false
      t.string :snapshot_timestamp, null: false

      t.timestamps
    end

    add_index :task_completion_snapshots, [:unit_id, :snapshot_timestamp], unique: true
  end
end
