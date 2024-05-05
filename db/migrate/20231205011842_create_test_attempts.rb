class CreateTestAttempts < ActiveRecord::Migration[7.0]
  def change
    create_table :test_attempts do |t|
      t.references :task
      t.string :name
      t.integer :attempt_number, default: 1, null: false
      t.boolean :pass_status
      t.text :suspend_data
      t.boolean :completed, default: false
      t.datetime :attempted_at
      t.string :cmi_entry, default: "ab-initio"
      t.string :exam_result
      t.timestamps
    end
  end
end
