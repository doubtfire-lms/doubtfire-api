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
      t.boolean :auto_sync_students, null: false, default: false
      t.boolean :auto_sync_extensions, null: false, default: false
      t.boolean :group_mapping_enabled, null: false, default: false

      t.timestamps
    end

    create_table :moodle_group_mappings do |t|
      t.references :moodle_integration, null: false
      t.bigint :moodle_group_id, null: false
      t.string :moodle_group_name, null: false
      t.string :target_type, null: false
      t.references :group_set
      t.references :group
      t.references :campus
      t.references :tutorial_stream
      t.references :tutorial
      t.boolean :create_if_missing, null: false, default: false

      t.timestamps
    end

    add_index :moodle_group_mappings,
              [:moodle_integration_id, :moodle_group_id],
              unique: true,
              name: 'index_moodle_group_mappings_on_integration_and_group'
  end
end
