class CreateTestAttempts < ActiveRecord::Migration[7.0]
  def change
    create_table :test_attempts do |t|
      t.references :task
      t.datetime :attempted_time, null: false
      t.boolean :terminated, default: false
      t.boolean :completion_status, default: false
      t.boolean :success_status, default: false
      t.float :score_scaled, default: 0
      t.text :cmi_datamodel
    end
  end
end
