class AddTiiDetails < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :tii_eula_version, :string
    add_column :users, :tii_eula_date, :datetime
    add_column :users, :tii_eula_version_confirmed, :boolean, default: false, null: false

    add_column :units, :tii_group_context_id, :string

    add_column :task_definitions, :tii_group_id, :string
    add_column :task_definitions, :moss_language, :string

    rename_table :plagiarism_match_links, :task_similarities

    add_column :task_similarities, :type, :string
    rename_column :task_similarities, :dismissed, :flagged

    remove_column :tasks, :max_pct_similar, :integer
    remove_column :projects, :max_pct_similar, :integer

    create_table :tii_submissions do |t|
      t.references  :task, null: false
      t.references  :tii_task_similarity, null: true

      t.bigint      :submitted_by_user_id, null: false
      t.index       :submitted_by_user_id
      t.string      :filename, null: false
      t.integer     :idx, null: false

      t.string      :submission_id
      t.string      :similarity_pdf_id

      t.datetime    :submitted_at
      t.datetime    :similarity_request_at

      t.integer     :status, default: 0, null: false
      t.integer     :overall_match_percentage

      t.timestamps  null: false
    end

    add_reference :task_similarities, :tii_submission, null: true

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
      t.datetime    :complete_at
      t.boolean     :retry, default: true, null: false

      t.integer     :error_code
      t.text        :custom_error_message

      t.text        :log, default: "[]"
      t.text        :params, default: "{}"

      t.timestamps

      t.index :retry
      t.index :complete
    end

    TaskSimilarity.update_all(type: 'MossTaskSimilarity')
    # TaskSimilarity.update_all('flagged = not flagged')

    TaskDefinition.find_in_batches do |batch|
      require 'json'

      batch.each do |task_definition|
        next unless task_definition.plagiarism_checks.present?
        plagiarism_checks = JSON.parse(task_definition.plagiarism_checks)

        next unless plagiarism_checks.any?

        task_definition.update(moss_language: plagiarism_checks.first['type'])
        task_definition.upload_requirements.each do |upload_requirement|
          next unless upload_requirement['type'] == 'code'
          upload_requirement['tii_check'] = true
        end
        task_definition.save
      end
    end

    remove_column :task_definitions, :plagiarism_checks, :string
  end
end
