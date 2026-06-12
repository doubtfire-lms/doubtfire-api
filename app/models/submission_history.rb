require 'zip'
require 'stringio'

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

    temporary_history = "#{history.archive_file_name}.tmp-#{SecureRandom.hex(8)}"
    copied_files = 0
    archive_updated = false
    begin
      Zip::File.open(temporary_history, create: true) do |destination|
        copy_archive_entries(history.archive_file_name, destination) if File.exist?(history.archive_file_name)

        Zip::File.open(source_path) do |source|
          source.each do |entry|
            next if entry.name_is_directory?

            file_name = entry.name.split('/').last
            next unless file_name&.match?(/^\d{3}-(?:document|code|image|zip|archive)/)
            next unless enabled_indexes.include?(file_name.to_i)

            destination.get_output_stream(File.join(history.entry_prefix, entry.name)) do |output|
              entry.get_input_stream { |input| IO.copy_stream(input, output) }
            end
            copied_files += 1
          end
        end
      end

      raise 'No selected submission files were found in the completed submission' if copied_files.zero?

      FileUtils.mv(temporary_history, history.archive_file_name)
      archive_updated = true
      system('chmod', 'o+w', history.output_path)
      history.save!
      history
    ensure
      FileUtils.rm_f(temporary_history)
      history.delete_associated_files if archive_updated && !history.persisted?
      if !history.persisted? && Dir.exist?(history.output_path) && Dir.empty?(history.output_path)
        FileUtils.rm_rf(history.output_path)
      end
    end
  end

  def output_path
    FileHelper.task_submission_identifier_path(:done, task)
  end

  def archive_file_name
    File.join(output_path, 'history.zip')
  end

  def entry_prefix
    "#{FileHelper.sanitized_path(submission_timestamp.to_s)}/"
  end

  def submission_entry_prefix
    File.join(entry_prefix, task.id.to_s, '/')
  end

  # Kept for Overseer compatibility; submissions are entries within this archive.
  def submission_zip_file_name
    archive_file_name
  end

  def submission_zip_data
    buffer = Zip::OutputStream.write_buffer do |output|
      Zip::File.open(archive_file_name) do |archive|
        submission_entries(archive).each do |entry|
          output.put_next_entry(entry.name.delete_prefix(entry_prefix))
          entry.get_input_stream { |input| IO.copy_stream(input, output) }
        end
      end
    end

    buffer.string
  end

  def has_submission_files? # rubocop:disable Naming/PredicateName
    return false unless File.exist?(archive_file_name)

    Zip::File.open(archive_file_name) { |archive| submission_entries(archive).any? }
  rescue Zip::Error
    false
  end

  def delete_associated_files
    return unless File.exist?(archive_file_name)

    temporary_history = "#{archive_file_name}.tmp-#{SecureRandom.hex(8)}"

    Zip::File.open(temporary_history, create: true) do |destination|
      self.class.copy_archive_entries(archive_file_name, destination, excluding_prefix: entry_prefix)
    end

    if Zip::File.open(temporary_history) { |archive| archive.entries.empty? }
      FileUtils.rm_f(archive_file_name)
      FileUtils.rm_f(temporary_history)
      FileUtils.rm_rf(output_path) if Dir.empty?(output_path)
    else
      FileUtils.mv(temporary_history, archive_file_name)
    end
  ensure
    FileUtils.rm_f(temporary_history) if temporary_history
  end

  def submission_entries(archive)
    archive.entries.reject(&:name_is_directory?).select do |entry|
      entry.name.start_with?(submission_entry_prefix)
    end
  end

  def self.copy_archive_entries(source_path, destination, excluding_prefix: nil)
    Zip::File.open(source_path) do |source|
      source.each do |entry|
        next if excluding_prefix && entry.name.start_with?(excluding_prefix)

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
