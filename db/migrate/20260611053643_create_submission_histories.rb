# rubocop:disable Rails/SkipsModelValidations
class CreateSubmissionHistories < ActiveRecord::Migration[8.0]
  # Migration-local models provide direct access to the tables as they exist at
  # this migration point, without using future application callbacks or validations.
  class MigrationTaskDefinition < ApplicationRecord
    self.table_name = 'task_definitions'
  end

  class MigrationOverseerAssessment < ApplicationRecord
    self.table_name = 'overseer_assessments'
  end

  class MigrationSubmissionHistory < ApplicationRecord
    self.table_name = 'submission_histories'
  end

  # `up` applies the migration when moving the database to this version.
  def up
    # Store one completed submission-history archive per task and timestamp.
    create_table :submission_histories do |t|
      t.references :task, null: false
      t.string :submission_timestamp, null: false

      t.timestamps
    end

    add_index :submission_histories,
              [:task_id, :submission_timestamp],
              unique: true,
              name: 'index_submission_histories_on_task_and_timestamp'

    # Enable submission history for every existing upload requirement. Preserve
    # an explicit value if this key has already been added to a requirement.
    MigrationTaskDefinition.reset_column_information
    MigrationTaskDefinition.find_each do |task_definition|
      requirements = JSON.parse(task_definition.upload_requirements.presence || '[]')
      next unless requirements.is_a?(Array)

      requirements.each do |requirement|
        next unless requirement.is_a?(Hash)
        next if requirement.key?('submission_history')

        requirement['submission_history'] = true
      end

      task_definition.update_columns(upload_requirements: requirements.to_json)
    rescue JSON::ParserError
      next
    end

    # Add the association as nullable first because existing Overseer assessments
    # do not have a submission-history row yet.
    add_reference :overseer_assessments, :submission_history, index: false

    # Refresh Active Record's cached columns after creating the table and column.
    MigrationOverseerAssessment.reset_column_information
    MigrationSubmissionHistory.reset_column_information

    # Preserve existing Overseer archives by creating a history with the same
    # task and timestamp, then linking the assessment to that history.
    MigrationOverseerAssessment.find_each do |assessment|
      history = MigrationSubmissionHistory.find_or_create_by!(
        task_id: assessment.task_id,
        submission_timestamp: assessment.submission_timestamp
      )
      assessment.update_columns(submission_history_id: history.id)
    end

    # Once all existing rows are linked, make the association required and
    # ensure a submission history cannot belong to multiple Overseer assessments.
    change_column_null :overseer_assessments, :submission_history_id, false
    add_index :overseer_assessments, :submission_history_id, unique: true
  end

  # `down` reverses `up` when rolling the database back from this version.
  def down
    # Remove the dependent association before removing its referenced table.
    remove_reference :overseer_assessments, :submission_history

    # Restore upload requirements to their shape before this migration.
    MigrationTaskDefinition.find_each do |task_definition|
      requirements = JSON.parse(task_definition.upload_requirements.presence || '[]')
      next unless requirements.is_a?(Array)

      requirements.each do |requirement|
        requirement.delete('submission_history') if requirement.is_a?(Hash)
      end

      task_definition.update_columns(upload_requirements: requirements.to_json)
    rescue JSON::ParserError
      next
    end

    # Submission-history rows are no longer needed after the association and
    # upload-requirement configuration have been removed.
    drop_table :submission_histories
  end
end
# rubocop:enable Rails/SkipsModelValidations
