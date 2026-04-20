# frozen_string_literal: true

class TaskCompletionSnapshot < ApplicationRecord
  include FileHelper

  belongs_to :unit

  validates :snapshot_timestamp, presence: true
  validates :snapshot_timestamp, uniqueness: { scope: :unit_id }

  after_destroy :delete_snapshot_file

  def snapshot_file_path
    FileHelper.unit_task_status_snapshot_path(unit, snapshot_timestamp, create: true)
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
    if File.exist?(snapshot_file_path)
      JSON.parse(File.read(snapshot_file_path))
    else
      {}
    end
  rescue JSON::ParserError
    {}
  end

  def store_stats!(payload)
    FileUtils.mkdir_p(File.dirname(snapshot_file_path))

    tmp_path = "#{snapshot_file_path}.tmp"
    File.write(tmp_path, JSON.pretty_generate(payload))
    FileUtils.mv(tmp_path, snapshot_file_path)
  ensure
    FileUtils.rm_f(tmp_path) if defined?(tmp_path)
  end

  private

  def delete_snapshot_file
    FileUtils.rm_f(snapshot_file_path)
  end
end
