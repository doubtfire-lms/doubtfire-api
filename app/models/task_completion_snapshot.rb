# frozen_string_literal: true

require 'csv'
require 'zip'

class TaskCompletionSnapshot < ApplicationRecord
  include FileHelper

  belongs_to :unit

  validates :snapshot_timestamp, presence: true
  validates :snapshot_timestamp, uniqueness: { scope: :unit_id }

  after_destroy :delete_snapshot_file

  def snapshot_file_path
    return nil if unit.blank?
    FileHelper.unit_task_status_snapshot_path(unit, create: true)
  end

  def snapshot_contents
    file_path = snapshot_file_path
    return nil if file_path.blank?
    if File.exist?(file_path)
      return read_csv_from_zip(file_path, snapshot_timestamp)
    end
    nil
  rescue Zip::Error
    nil
  end

  def snapshot_date
    return nil if snapshot_timestamp.blank?

    snapshot_time.to_date
  end

  def snapshot_time
    return nil if snapshot_timestamp.blank?

    Time.zone.at(snapshot_timestamp.to_i)
  end

  def load_stats
    snapshot_contents = self.snapshot_contents

    return {} if snapshot_contents.blank?

    parse_csv_stats(snapshot_contents)
  rescue CSV::MalformedCSVError
    {}
  end

  def store_stats!(payload)
    file_path = snapshot_file_path
    raise 'Cannot store stats without a unit' if file_path.blank?

    FileUtils.mkdir_p(File.dirname(file_path))

    csv_filename = FileHelper.snapshot_csv_filename(snapshot_timestamp)
    raise 'Cannot store stats without a valid snapshot timestamp' if csv_filename.blank?

    tmp_path = "#{file_path}.tmp"

    # Read existing zip entries (if file exists)
    existing_entries = {}
    if File.exist?(file_path)
      Zip::File.open(file_path) do |zip_file|
        zip_file.each do |entry|
          next if entry.directory?
          existing_entries[entry.name] = entry.get_input_stream.read
        end
      end
    end

    # Update or add the current snapshot entry
    existing_entries[csv_filename] = payload.to_s

    # Write the zip file with all entries
    Zip::OutputStream.open(tmp_path) do |zip|
      existing_entries.each do |filename, content|
        zip.put_next_entry(filename)
        zip.write(content)
      end
    end

    FileUtils.mv(tmp_path, file_path)
  ensure
    FileUtils.rm_f(tmp_path) if defined?(tmp_path) && tmp_path
  end

  private

  def parse_csv_stats(csv_text)
    csv = CSV.parse(csv_text, headers: true)
    return {} if csv.empty?

    stream_headers = unit.tutorial_streams.pluck(:abbreviation)
    stream_headers = ['Tutorial'] if stream_headers.empty?
    task_definitions = unit.task_definitions_by_grade

    stats = Hash.new { |hash, key| hash[key] = Hash.new { |tutorial_hash, tutorial_key| tutorial_hash[tutorial_key] = Hash.new { |task_hash, task_key| task_hash[task_key] = Hash.new(0) } } }

    csv.each do |row|
      campus_abbreviation = row['Campus'].to_s.strip
      next if campus_abbreviation.blank?

      campus_name = Campus.find_by(abbreviation: campus_abbreviation)&.name || campus_abbreviation

      stream_headers.each do |stream_header|
        tutorial_name = row[stream_header].to_s.strip
        next if tutorial_name.blank?

        task_definitions.each do |task_definition|
          status_value = row[task_definition.abbreviation].to_s.strip
          status_key = TaskStatus.id_to_key(status_value.to_i) || :not_started
          stats[campus_name][tutorial_name][task_definition.abbreviation][status_key.to_s] += 1
        end
      end
    end

    stats
  end

  def read_csv_from_zip(zip_path, snapshot_timestamp)
    csv_filename = FileHelper.snapshot_csv_filename(snapshot_timestamp)
    Zip::File.open(zip_path) do |zip_file|
      entry = zip_file.find_entry(csv_filename)
      return nil if entry.nil?

      entry.get_input_stream.read
    end
  end

  def delete_snapshot_file
    return if snapshot_timestamp.blank?

    file_path = snapshot_file_path
    return if file_path.blank? || !File.exist?(file_path)

    csv_filename = FileHelper.snapshot_csv_filename(snapshot_timestamp)
    return if csv_filename.blank?

    tmp_path = "#{file_path}.tmp"

    begin
      # Read existing zip entries excluding the one we want to delete
      remaining_entries = {}
      Zip::File.open(file_path) do |zip_file|
        zip_file.each do |entry|
          next if entry.directory?
          next if entry.name == csv_filename
          remaining_entries[entry.name] = entry.get_input_stream.read
        end
      end

      if remaining_entries.empty?
        # If no entries left, just delete the zip file
        FileUtils.rm_f(file_path)
      else
        # Write the zip file with remaining entries
        Zip::OutputStream.open(tmp_path) do |zip|
          remaining_entries.each do |filename, content|
            zip.put_next_entry(filename)
            zip.write(content)
          end
        end
        FileUtils.mv(tmp_path, file_path)
      end
    rescue StandardError => e
      # If anything goes wrong with zip operations, just clean up and log
      logger.error("Error managing snapshot zip file: #{e.message}")
      FileUtils.rm_f(tmp_path)
    end
  end
end
