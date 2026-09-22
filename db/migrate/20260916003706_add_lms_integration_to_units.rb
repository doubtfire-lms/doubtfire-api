class AddLmsIntegrationToUnits < ActiveRecord::Migration[8.0]
  def change
    create_table :lms_integrations do |t|
      t.references :unit, null: false, index: { unique: true }
      # Where course data comes from, so other sources such as a direct Moodle web service can be added later.
      t.string :source, null: false, default: 'lti'
      t.bigint :assignment_id
      t.string :assignment_name
      t.boolean :fetch_extensions, null: false, default: false
      t.boolean :auto_sync_students, null: false, default: false
      t.boolean :withdraw_missing_students, null: false, default: false
      t.boolean :auto_sync_extensions, null: false, default: false
      t.boolean :group_mapping_enabled, null: false, default: false
      t.boolean :skip_ungraded, null: false, default: true
      t.boolean :send_grade_rationale, null: false, default: false
      t.boolean :validated, null: false, default: false
      t.datetime :validated_at
      # Set by the first failed scheduled sync and cleared by the next one that succeeds
      t.datetime :auto_sync_failing_since
      t.text :auto_sync_last_error

      t.timestamps
    end

    create_table :lms_group_mappings do |t|
      t.references :lms_integration, null: false
      t.bigint :lms_group_id, null: false
      t.string :lms_group_name, null: false
      t.string :target_type, null: false
      t.references :group_set
      t.references :group
      t.references :campus
      t.references :tutorial_stream
      t.references :tutorial
      t.boolean :create_if_missing, null: false, default: false

      t.timestamps
    end

    add_index :lms_group_mappings,
              [:lms_integration_id, :lms_group_id],
              name: 'index_lms_group_mappings_on_integration_and_group'
  end
end
