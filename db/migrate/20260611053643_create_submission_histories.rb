# rubocop:disable Rails/SkipsModelValidations
require 'zip'

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

  class MigrationTask < ApplicationRecord
    self.table_name = 'tasks'
    belongs_to :project, class_name: 'CreateSubmissionHistories::MigrationProject'
  end

  class MigrationProject < ApplicationRecord
    self.table_name = 'projects'
    belongs_to :unit, class_name: 'CreateSubmissionHistories::MigrationUnit'
    belongs_to :user, class_name: 'CreateSubmissionHistories::MigrationUser'

    def student
      user
    end
  end

  class MigrationUnit < ApplicationRecord
    self.table_name = 'units'
  end

  class MigrationUser < ApplicationRecord
    self.table_name = 'users'
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

    # Enable submission history for existing Overseer task definitions. Preserve
    # an explicit value if this key has already been added to a requirement.
    MigrationTaskDefinition.reset_column_information
    MigrationTaskDefinition.find_each do |task_definition|
      requirements = JSON.parse(task_definition.upload_requirements.presence || '[]')
      next unless requirements.is_a?(Array)

      requirements.each do |requirement|
        next unless requirement.is_a?(Hash)
        next if requirement.key?('submission_history')

        requirement['submission_history'] = task_definition.assessment_enabled?
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

    # Replace each task's timestamp directories with one history.zip. Every
    # directory and filename is preserved inside the archive.
    MigrationSubmissionHistory.distinct.pluck(:task_id).each do |task_id|
      task = MigrationTask.find_by(id: task_id)
      archive_existing_history_directories(task) if task
    end

    # Once all existing rows are linked, make the association required and
    # ensure a submission history cannot belong to multiple Overseer assessments.
    change_column_null :overseer_assessments, :submission_history_id, false
    add_index :overseer_assessments, :submission_history_id, unique: true
  end

  # `down` reverses `up` when rolling the database back from this version.
  def down
    # Restore timestamp directories before removing the records that identify
    # which task archives need to be unpacked.
    MigrationSubmissionHistory.distinct.pluck(:task_id).each do |task_id|
      task = MigrationTask.find_by(id: task_id)
      restore_history_directories(task) if task
    end

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

  private

  def archive_existing_history_directories(task)
    task_path = FileHelper.task_submission_identifier_path(:done, task)
    return unless Dir.exist?(task_path)

    directories = Dir.children(task_path).filter_map do |name|
      path = File.join(task_path, name)
      [name, path] if File.directory?(path)
    end
    return if directories.empty?

    archive_path = File.join(task_path, 'history.zip')
    temporary_path = "#{archive_path}.tmp-#{SecureRandom.hex(8)}"

    Zip::File.open(temporary_path, create: true) do |archive|
      copy_zip_entries(archive_path, archive) if File.exist?(archive_path)
      directories.each { |name, path| add_directory_to_zip(archive, name, path) }
    end

    FileUtils.mv(temporary_path, archive_path)
    directories.each { |directory| FileUtils.rm_rf(directory.last) }
  ensure
    FileUtils.rm_f(temporary_path) if temporary_path
  end

  def restore_history_directories(task)
    task_path = FileHelper.task_submission_identifier_path(:done, task)
    archive_path = File.join(task_path, 'history.zip')
    return unless File.exist?(archive_path)

    Zip::File.open(archive_path) do |archive|
      archive.each do |entry|
        destination = File.join(task_path, entry.name)
        FileUtils.mkdir_p(entry.name_is_directory? ? destination : File.dirname(destination))
        entry.extract(destination) { true } unless entry.name_is_directory?
      end
    end

    FileUtils.rm_f(archive_path)
  end

  def add_directory_to_zip(archive, root_name, path)
    archive.mkdir("#{root_name}/") unless archive.find_entry("#{root_name}/")

    Dir.glob(File.join(path, '**', '*'), File::FNM_DOTMATCH).sort.each do |source|
      next if ['.', '..'].include?(File.basename(source))

      relative_path = File.join(root_name, source.delete_prefix("#{path}/"))
      if File.directory?(source)
        archive.mkdir("#{relative_path}/") unless archive.find_entry("#{relative_path}/")
      else
        archive.add(relative_path, source)
      end
    end
  end

  def copy_zip_entries(source_path, destination)
    Zip::File.open(source_path) do |source|
      source.each do |entry|
        if entry.name_is_directory?
          destination.mkdir(entry.name) unless destination.find_entry(entry.name)
        else
          destination.get_output_stream(entry.name) do |output|
            entry.get_input_stream { |input| IO.copy_stream(input, output) }
          end
        end
      end
    end
  end
end
# rubocop:enable Rails/SkipsModelValidations
