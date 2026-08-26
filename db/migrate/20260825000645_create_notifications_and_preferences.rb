class CreateNotificationsAndPreferences < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :recipient, null: false, index: false
      t.references :unit, null: false
      t.references :project, null: true
      t.references :task, null: true
      t.references :actor, null: true

      t.string :kind, null: false, limit: 64
      # Identifies the event, so cron re-runs and job retries cannot raise it twice.
      t.string :deduplication_key, null: false, limit: 191

      # What raised the notification
      t.references :task_comment, null: true
      t.references :overseer_assessment, null: true, index: false
      t.references :tutor_note, null: true, index: false

      # Set only for the kinds that need them
      t.references :task_status, null: true, index: false # what a status change moved to
      t.references :unit_role, null: true, index: false # whose moderation notes were written on
      t.date :discuss_deadline, null: true # when the task has to be discussed by

      t.datetime :read_at
      t.datetime :email_processed_at
      t.datetime :email_sent_at
      t.datetime :email_not_before # holds a failed run back until the student has had a chance to read it

      t.timestamps
    end

    add_index :notifications, [:recipient_id, :deduplication_key],
              unique: true,
              name: 'index_notifications_on_recipient_and_deduplication_key'
    add_index :notifications, [:recipient_id, :read_at, :created_at],
              name: 'index_notifications_on_recipient_read_created'
    add_index :notifications, [:recipient_id, :unit_id, :email_processed_at],
              name: 'index_notifications_for_email_delivery'
    add_index :notifications, [:recipient_id, :task_id, :read_at],
              name: 'index_notifications_on_recipient_task_read'

    # One row per user. `channels` maps each notification to the channels it is
    # delivered on, and applies to every unit the user is in:
    #
    #   { "new_task_comment" => ["in_app", "email"], "overseer_failed" => [] }
    #
    create_table :notification_settings do |t|
      t.references :user, null: false, index: { unique: true }

      t.json :channels, null: false

      t.string :digest_frequency, null: false, default: 'weekly', limit: 16
      t.string :digest_time, null: false, default: '07:00', limit: 5
      t.integer :digest_weekday, null: false, default: 1
      t.boolean :weekly_summary, null: false, default: true
      t.datetime :next_digest_at
      t.datetime :last_digest_at

      t.timestamps
    end

    add_index :notification_settings, :next_digest_at

    # One row per unit the user has changed, holding only what differs from their
    # notification_settings. A muted unit sends nothing, and null channels mean
    # the unit still uses the channels from notification_settings.
    create_table :notification_unit_overrides do |t|
      t.references :user, null: false, index: false
      t.references :unit, null: false

      t.boolean :muted, null: false, default: false
      t.json :channels, null: true

      t.timestamps
    end

    add_index :notification_unit_overrides, [:user_id, :unit_id],
              unique: true,
              name: 'index_notification_unit_overrides_on_user_and_unit'
  end
end
