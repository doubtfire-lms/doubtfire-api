require 'zip'

class SubmissionHistory < ApplicationRecord
  belongs_to :task, optional: false
  has_one :overseer_assessment, dependent: :destroy

  validates :submission_timestamp, presence: true, uniqueness: { scope: :task_id }

  after_destroy :delete_associated_files

  def self.enabled_requirements(task)
    task.upload_requirements.each_index.select do |index|
      task.upload_requirements[index]['submission_history'] == true
    end
  end

  def self.create_archive!(task, submission_timestamp)
    if exists?(task: task, submission_timestamp: submission_timestamp.to_s)
      raise ActiveRecord::RecordNotUnique, 'Submission history already exists for this task and timestamp'
    end

    enabled_indexes = enabled_requirements(task)
    raise 'No upload requirements are enabled for submission history' if enabled_indexes.empty?

    source_path = FileHelper.zip_file_path_for_done_task(task)
    raise "Submission file not found: #{source_path}" unless File.exist?(source_path)

    history = new(task: task, submission_timestamp: submission_timestamp.to_s)
    FileUtils.mkdir_p(history.output_path)

    temporary_path = "#{history.submission_zip_file_name}.tmp-#{SecureRandom.hex(8)}"
    copied_files = 0
    begin
      Zip::File.open(temporary_path, create: true) do |destination|
        Zip::File.open(source_path) do |source|
          source.each do |entry|
            next if entry.name_is_directory?

            file_name = entry.name.split('/').last
            next unless file_name&.match?(/^\d{3}-(?:document|code|image|zip|archive)/)
            next unless enabled_indexes.include?(file_name.to_i)

            destination.get_output_stream(entry.name) do |output|
              entry.get_input_stream { |input| IO.copy_stream(input, output) }
            end
            copied_files += 1
          end
        end
      end

      raise 'No selected submission files were found in the completed submission' if copied_files.zero?

      FileUtils.mv(temporary_path, history.submission_zip_file_name)
      system('chmod', 'o+w', history.output_path)
      history.save!
      history
    ensure
      FileUtils.rm_f(temporary_path)
      FileUtils.rm_rf(history.output_path) unless history.persisted?
    end
  end

  def output_path
    FileHelper.task_submission_identifier_path_with_timestamp(:done, task, submission_timestamp)
  end

  def submission_zip_file_name
    File.join(output_path, 'submission.zip')
  end

  def has_submission_files? # rubocop:disable Naming/PredicateName
    File.exist?(submission_zip_file_name)
  end

  def delete_associated_files
    FileUtils.rm_rf(output_path)
  end

  def self.pending_marker_path(task)
    File.join(FileHelper.task_submission_identifier_path(:pending, task), 'submission-history')
  end

  def self.mark_pending(task)
    marker_path = pending_marker_path(task)
    FileUtils.mkdir_p(File.dirname(marker_path))
    FileUtils.touch(marker_path)
  end

  def self.clear_pending(task)
    FileUtils.rm_f(pending_marker_path(task))
  end

  def self.pending?(task)
    File.exist?(pending_marker_path(task))
  end
end
