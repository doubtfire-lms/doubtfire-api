class AddD2l < ActiveRecord::Migration[7.1]
  def change
    # Create a table linked to the units table,
    # that captures the org unit id, and the grade object id for D2L
    create_table :d2l_assessment_mappings do |t|
      t.bigint :unit_id, null: false
      t.string :org_unit_id
      t.integer :grade_object_id
      t.timestamps

      t.index :unit_id, unique: true
    end

    create_table :user_oauth_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :provider, default: 0, null: false
      t.text :token
      t.datetime :expires_at
      t.timestamps
    end

    create_table :user_oauth_states do |t|
      t.references :user, null: false, foreign_key: true
      t.string :state
      t.timestamps

      t.index :state, unique: true
    end
  end
end
