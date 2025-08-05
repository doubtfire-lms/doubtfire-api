class CreateMarkingSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :marking_sessions do |t|
      t.references :marker, null: false, foreign_key: { to_table: :users }
      t.references :unit, null: false, foreign_key: true
      t.string :ip_address
      t.datetime :start_time
      t.datetime :end_time
      t.integer :duration_minutes

      t.timestamps
    end

    add_index :marking_sessions, [:marker_id, :unit_id, :ip_address, :updated_at], name: 'index_marking_sessions_on_user_unit_ip_and_time'
  end
end
