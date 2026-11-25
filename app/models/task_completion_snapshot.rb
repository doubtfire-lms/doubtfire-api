# frozen_string_literal: true

require 'csv'
require 'set'
require 'zip'

class TaskCompletionSnapshot < ApplicationRecord
  include FileHelper

  SUBMITTED_STATUS_KEYS = Set[
    :feedback_exceeded, :ready_for_feedback, :discuss, :demonstrate, :complete,
    :fail, :time_exceeded, :assess_in_portfolio, :attention_required, :rediscuss
  ].freeze

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

  # One entry of the unit's aggregated stats file. Only per target grade scopes are stored; the
  # client sums them for the whole cohort and reads tutorial buckets as the plain status stats.
  def aggregated_stats_entry
    student_counts = load_student_counts
    {
      'snapshot_date' => snapshot_date&.iso8601,
      'snapshot_timestamp' => snapshot_timestamp,
      'status_population_stats' => load_status_population_stats,
      'submitted_task_count_student_counts' => load_submitted_task_count_student_counts,
      'student_count' => student_counts['student_count'],
      'campus_student_counts' => student_counts['campus_student_counts'],
      'target_grade_student_counts' => student_counts['target_grade_student_counts'],
      'target_grade_campus_student_counts' => student_counts['target_grade_campus_student_counts']
    }
  end

  # Count each CSV row once for the whole campus, even when the student belongs
  # to multiple tutorial streams. Tutorial buckets remain available for filtering.
  def load_status_population_stats
    csv_text = snapshot_contents
    return { 'target_grades' => {} } if csv_text.blank?

    stream_headers = unit.tutorial_streams.pluck(:abbreviation)
    stream_headers = ['Tutorial'] if stream_headers.empty?
    task_definitions = unit.task_definitions_by_grade
    grade_labels = unit.grade_values.to_h { |grade| [unit.grade_label(grade), grade.to_s] }
    campus_names = Campus.pluck(:abbreviation, :name).to_h
    result = { 'target_grades' => {} }
    seen = Set.new

    CSV.parse(csv_text, headers: true).each do |row|
      student = row['Username'].presence || row['Student ID'].presence
      campus_abbreviation = row['Campus'].to_s.strip
      next if student.blank? || campus_abbreviation.blank?

      campus = campus_names[campus_abbreviation] || campus_abbreviation
      tutorial_names = stream_headers.filter_map { |header| row[header].to_s.strip.presence }.uniq
      # Unmatched grades still need a bucket, or the client's cohort totals would miss them.
      grade = grade_labels[row['Target Grade'].to_s.strip] || 'unknown'
      campus_stats = (result['target_grades'][grade] ||= {})[campus] ||= {}

      ['__all__', *tutorial_names].each do |tutorial|
        task_stats = campus_stats[tutorial] ||= {}
        task_definitions.each do |task_definition|
          next unless seen.add?([student, campus, tutorial, task_definition.abbreviation])

          status_id = row[task_definition.abbreviation].to_s.strip.to_i
          status = (TaskStatus.id_to_key(status_id) || :not_started).to_s
          counts = task_stats[task_definition.abbreviation] ||= {}
          counts[status] = (counts[status] || 0) + 1
        end
      end
    end

    result
  rescue CSV::MalformedCSVError
    { 'target_grades' => {} }
  end

  def load_student_counts
    students = Set.new
    campus_students = Hash.new { |hash, key| hash[key] = Set.new }
    target_grade_students = Hash.new { |hash, key| hash[key] = Set.new }
    target_grade_campus_students = Hash.new do |hash, key|
      hash[key] = Hash.new { |campus_hash, campus| campus_hash[campus] = Set.new }
    end

    CSV.parse(snapshot_contents.to_s, headers: true).each do |row|
      student = row['Username'].presence || row['Student ID'].presence
      next if student.blank?

      students.add(student)

      target_grade = unit.grade_values.find { |value| unit.grade_label(value) == row['Target Grade'].to_s.strip }
      target_grade_students[target_grade].add(student) if target_grade

      campus_abbreviation = row['Campus'].to_s.strip
      next if campus_abbreviation.blank?

      campus = Campus.find_by(abbreviation: campus_abbreviation)&.name || campus_abbreviation
      campus_students[campus].add(student)
      target_grade_campus_students[target_grade][campus].add(student) if target_grade
    end

    {
      'student_count' => students.length,
      'campus_student_counts' => campus_students.transform_values(&:length),
      'target_grade_student_counts' => target_grade_students.transform_keys(&:to_s).transform_values(&:length),
      'target_grade_campus_student_counts' => target_grade_campus_students.transform_keys(&:to_s).transform_values do |campuses|
        campuses.transform_values(&:length)
      end
    }
  rescue CSV::MalformedCSVError
    {
      'student_count' => 0,
      'campus_student_counts' => {},
      'target_grade_student_counts' => {},
      'target_grade_campus_student_counts' => {}
    }
  end

  # Students per student target grade ('unknown' when unmatched), campus and tutorial ('__all__' for any tutorial), keyed by
  # submitted task counts per task grade in task_grade_values order (e.g. "3,1,0,0").
  def load_submitted_task_count_student_counts
    csv_text = snapshot_contents
    grade_values = unit.grade_values
    result = { 'task_grade_values' => grade_values, 'target_grades' => {} }
    return result if csv_text.blank?

    stream_headers = unit.tutorial_streams.pluck(:abbreviation)
    stream_headers = ['Tutorial'] if stream_headers.empty?
    task_grades = unit.task_definitions_by_grade.pluck(:abbreviation, :target_grade)
    grade_labels = grade_values.to_h { |grade| [unit.grade_label(grade), grade.to_s] }
    campus_names = Campus.pluck(:abbreviation, :name).to_h
    seen_students = Set.new

    CSV.parse(csv_text, headers: true).each do |row|
      student = row['Username'].presence || row['Student ID'].presence
      campus_abbreviation = row['Campus'].to_s.strip
      next if student.blank? || campus_abbreviation.blank? || !seen_students.add?(student)

      submitted_counts = Hash.new(0)
      task_grades.each do |abbreviation, task_grade|
        submitted_counts[task_grade] += 1 if SUBMITTED_STATUS_KEYS.include?(TaskStatus.id_to_key(row[abbreviation].to_i))
      end
      key = grade_values.map { |grade| submitted_counts[grade] }.join(',')

      campus = campus_names[campus_abbreviation] || campus_abbreviation
      tutorials = ['__all__', *stream_headers.filter_map { |header| row[header].to_s.strip.presence }.uniq]
      target_grade = grade_labels[row['Target Grade'].to_s.strip] || 'unknown'
      campus_stats = (result['target_grades'][target_grade] ||= {})[campus] ||= {}
      tutorials.each do |tutorial|
        distribution = campus_stats[tutorial] ||= {}
        distribution[key] = (distribution[key] || 0) + 1
      end
    end

    result
  rescue CSV::MalformedCSVError
    { 'task_grade_values' => unit.grade_values, 'target_grades' => {} }
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
