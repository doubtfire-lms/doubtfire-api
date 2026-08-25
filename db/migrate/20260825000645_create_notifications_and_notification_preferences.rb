class CreateNotificationsAndNotificationPreferences < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :recipient, null: false
      t.references :unit, null: false
      t.references :project, null: true
      t.references :task, null: true
      t.references :actor, null: true

      t.string :kind, null: false, limit: 64
      t.string :source_type, null: true, limit: 64
      t.bigint :source_id, null: true
      t.string :deduplication_key, null: false, limit: 191
      t.json :metadata, null: false

      t.datetime :read_at
      t.datetime :email_processed_at
      t.datetime :email_sent_at

      t.timestamps
    end

    add_index :notifications, [:source_type, :source_id]
    add_index :notifications, [:recipient_id, :deduplication_key],
              unique: true,
              name: 'index_notifications_on_recipient_and_deduplication_key'
    add_index :notifications, [:recipient_id, :read_at, :created_at],
              name: 'index_notifications_on_recipient_read_created'
    add_index :notifications, [:recipient_id, :unit_id, :email_processed_at],
              name: 'index_notifications_for_email_delivery'
    add_index :notifications, [:recipient_id, :task_id, :read_at],
              name: 'index_notifications_on_recipient_task_read'

    create_table :notification_preferences do |t|
      t.references :user, null: false
      t.references :unit, null: false

      t.json :email_categories, null: false
      t.string :email_frequency, null: false, default: 'weekly', limit: 16
      t.string :email_time, null: false, default: '09:00', limit: 5
      t.integer :email_weekday, null: false, default: 1
      t.string :timezone, null: false, default: 'UTC'
      t.datetime :next_digest_at
      t.datetime :last_digest_at

      t.timestamps
    end

    add_index :notification_preferences, [:user_id, :unit_id],
              unique: true,
              name: 'index_notification_preferences_on_user_and_unit'
    add_index :notification_preferences, :next_digest_at
  end
end
