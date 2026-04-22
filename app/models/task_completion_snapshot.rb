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
    FileHelper.unit_task_status_snapshot_path(unit, snapshot_timestamp, create: true)
  end

  def snapshot_contents
    if File.exist?(snapshot_file_path)
      return read_csv_from_zip(snapshot_file_path)
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
    FileUtils.mkdir_p(File.dirname(snapshot_file_path))

    tmp_path = "#{snapshot_file_path}.tmp"
    Zip::OutputStream.open(tmp_path) do |zip|
      zip.put_next_entry('snapshot.csv')
      zip.write(payload.to_s)
    end

    FileUtils.mv(tmp_path, snapshot_file_path)
  ensure
    FileUtils.rm_f(tmp_path) if defined?(tmp_path)
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

  def read_csv_from_zip(zip_path)
    Zip::File.open(zip_path) do |zip_file|
      entry = zip_file.find_entry('snapshot.csv') || zip_file.entries.first
      return nil if entry.nil?

      entry.get_input_stream.read
    end
  end

  def delete_snapshot_file
    FileUtils.rm_f(snapshot_file_path)
  end
end
