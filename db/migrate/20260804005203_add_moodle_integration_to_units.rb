class AddMoodleIntegrationToUnits < ActiveRecord::Migration[8.0]
  def change
    add_column :units, :moodle_enabled, :boolean, null: false, default: false

    create_table :moodle_integrations do |t|
      t.references :unit, null: false, index: { unique: true }
      t.bigint :course_id, null: false
      t.text :api_key, null: false
      t.bigint :assignment_id
      t.string :assignment_name
      t.boolean :fetch_extensions, null: false, default: false

      t.timestamps
    end
  end
end
