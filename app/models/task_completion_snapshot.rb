# frozen_string_literal: true

require 'csv'

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
    return File.read(snapshot_file_path) if File.exist?(snapshot_file_path)

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
    File.write(tmp_path, payload.to_s)
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
      stream_headers.each do |stream_header|
        tutorial_name = row[stream_header].to_s.strip
        next if tutorial_name.blank?

        campus_name = if stream_header == 'Tutorial'
                        unit.tutorials.find_by(abbreviation: tutorial_name)&.campus&.name || stream_header
                      else
                        stream_header
                      end

        task_definitions.each do |task_definition|
          status_value = row[task_definition.abbreviation].to_s.strip
          status_key = TaskStatus.id_to_key(status_value.to_i) || :not_started
          stats[campus_name][tutorial_name][task_definition.abbreviation][status_key.to_s] += 1
        end
      end
    end

    stats
  end

  def delete_snapshot_file
    FileUtils.rm_f(snapshot_file_path)
  end
end
