class AddTiiDetails < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :tii_eula_version, :string
    add_column :users, :tii_eula_date, :datetime
    add_column :users, :tii_eula_version_confirmed, :boolean, default: false, null: false
    add_column :units, :tii_group_context_id, :string
    add_column :task_definitions, :tii_group_id, :string

    create_table :tii_submissions do |t|
      t.references  :task, null: false
      t.bigint      :submitted_by_user_id, null: false
      t.index       :submitted_by_user_id
      t.string      :filename, null: false
      t.integer     :idx, nul: false

      t.string      :submission_id
      t.string      :similarity_pdf_id

      t.datetime    :submitted_at
      t.datetime    :similarity_request_at

      t.integer     :status, default: 0, null: false
      t.integer     :overall_match_percentage
      t.boolean     :flagged, default: false, null: false

      t.timestamps  null: false
    end

    create_table :tii_group_attachments do |t|
      t.references  :task_definition, null: false

      t.string      :filename, null: false

      t.string      :group_attachment_id
      t.string      :file_sha1_digest

      t.integer     :status, default: 0, null: false

      t.timestamps  null: false
    end

    create_table :tii_actions do |t|
      t.references  :entity, polymorphic: true

      t.string      :type
      t.boolean     :complete, default: false, null: false
      t.integer     :retries, default: 0, null: false

      t.datetime    :last_run
      t.boolean     :retry, default: true, null: false

      t.integer     :error_code
      t.text        :custom_error_message

      t.json        :log, default: []
      t.json        :params, default: {}

      t.timestamps

      t.index :retry
      t.index :complete
    end
  end
end
