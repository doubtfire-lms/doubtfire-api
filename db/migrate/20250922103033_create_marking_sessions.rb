class CreateMarkingSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :marking_sessions do |t|
      t.references :user, null: false
      t.references :unit, null: false
      t.string :ip_address
      t.datetime :start_time
      t.datetime :end_time

      t.timestamps
    end

    add_index :marking_sessions, [:user_id, :unit_id, :ip_address, :updated_at], name: 'index_marking_sessions_on_user_unit_ip_and_time'
  end
end
