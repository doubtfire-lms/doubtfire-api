# rubocop:disable Rails/SkipsModelValidations
class CreateSubmissionHistories < ActiveRecord::Migration[8.0]
  class MigrationTaskDefinition < ActiveRecord::Base
    self.table_name = 'task_definitions'
  end

  def up
    create_table :submission_histories do |t|
      t.references :task, null: false
      t.string :submission_timestamp, null: false

      t.timestamps
    end

    add_index :submission_histories,
              [:task_id, :submission_timestamp],
              unique: true,
              name: 'index_submission_histories_on_task_and_timestamp'

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
  end

  def down
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

    drop_table :submission_histories
  end
end
# rubocop:enable Rails/SkipsModelValidations
