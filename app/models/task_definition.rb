require 'json'

class TaskDefinition < ApplicationRecord
  before_destroy :delete_associated_files

  after_update :move_files_on_abbreviation_change, if: :saved_change_to_abbreviation?
  after_update :remove_old_group_submissions, if: :has_removed_group?
  after_update :check_and_update_tii_status, if: :saved_change_to_upload_requirements?
  after_update :update_tii_group, if: :saved_change_to_due_date?

  # Model associations
  belongs_to :unit, optional: false # Foreign key
  belongs_to :group_set, optional: true
  belongs_to :tutorial_stream, optional: true
  belongs_to :overseer_image, optional: true

  has_many :tasks, dependent:  :destroy # Destroying a task definition will also nuke any instances
  has_many :group_submissions, dependent: :destroy # Destroying a task definition will also nuke any group submissions
  has_many :learning_outcome_task_links, dependent: :destroy # links to learning outcomes
  has_many :learning_outcomes, -> { where('learning_outcome_task_links.task_id is NULL') }, through: :learning_outcome_task_links # only link staff relations

  has_many :tii_group_attachments, dependent: :destroy # destroy uploaded files to tii - after the tasks
  has_many :tii_actions, as: :entity, dependent: :destroy

  serialize :upload_requirements, coder: JSON

  # Model validations/constraints
  validates :name, uniqueness: { scope:  :unit_id } # task definition names within a unit must be unique
  validates :abbreviation, uniqueness: { scope: :unit_id } # task definition names within a unit must be unique

  validates :target_grade, inclusion: { in: GradeHelper::RANGE, message: '%{value} is not a valid target grade' }
  validates :max_quality_pts, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, message: 'must be between 0 and 100' }

  validate :upload_requirements, :check_upload_requirements_format

  validates :description, length: { maximum: 4095, allow_blank: true }

  validate :ensure_no_submissions, if: :will_save_change_to_group_set_id?
  validate :unit_must_be_same
  validate :tutorial_stream_present?

  validates :weighting, presence: true

  include TaskDefinitionTiiModule
  include TaskDefinitionSimilarityModule

  def unit_must_be_same
    if unit.present? and tutorial_stream.present? and not unit.eql? tutorial_stream.unit
      errors.add(:unit, "should be same as the unit in the associated tutorial stream")
    end
  end

  def tutorial_stream_present?
    if tutorial_stream.nil? and unit.tutorial_streams.exists?
      errors.add(:tutorial_stream, "must be one of the tutorial streams in the unit")
    end
  end

  # In the rollover process, copy this definition into another unit
  # Copy this task into the other unit
  def copy_to(other_unit)
    new_td = self.dup

    # change the unit...
    new_td.unit_id = other_unit.id          # for database
    new_td.unit = other_unit                # for other operations
    other_unit.task_definitions << new_td   # so we can see it in unit elsewhere

    # Change tutorial stream
    new_td.tutorial_stream = other_unit.tutorial_streams.find_by(abbreviation: tutorial_stream.abbreviation) unless tutorial_stream.nil?

    # change group set
    if is_group_task?
      # Find based upon the group set in the new unit
      new_td.group_set = other_unit.group_sets.find_by(name: self.group_set.name)
    end

    # Adjust dates
    new_td.start_week_and_day = start_week, start_day
    new_td.target_week_and_day = target_week, target_day

    if self['due_date'].present?
      new_td.due_week_and_day = due_week, due_day
    end

    # Ensure we have the dir for the destination task sheet
    FileHelper.task_file_dir_for_unit(other_unit, create = true)

    if has_task_sheet?
      FileUtils.cp(task_sheet, new_td.task_sheet())
    end

    if has_task_resources?
      # Copy the task resources, and trigger tii integration if needed
      new_td.add_task_resources(task_resources, copy: true)
    end

    new_td.save!

    new_td
  end

  def has_removed_group?
    saved_change_to_group_set_id? && group_set_id.nil?
  end

  def ensure_no_submissions
    if tasks.where("submission_date IS NOT NULL").count() > 0
      errors.add(:group_set, "Unable to change group status of task as submissions exist")
    end
  end

  def remove_old_group_submissions
    if group_set_id.nil? && group_submissions.count > 0
      group_submissions.destroy_all
    end
  end

  def detailed_name
    "#{abbreviation} #{name}"
  end

  def move_files_on_abbreviation_change
    old_abbr = saved_change_to_abbreviation[0] # 0 is original abbreviation
    if File.exist? task_sheet_with_abbreviation(old_abbr)
      FileUtils.mv(task_sheet_with_abbreviation(old_abbr), task_sheet())
    end

    if File.exist? task_resources_with_abbreviation(old_abbr)
      FileUtils.mv(task_resources_with_abbreviation(old_abbr), task_resources())
    end

    if File.exist? task_assessment_resources_with_abbreviation(old_abbr)
      FileUtils.mv(task_assessment_resources_with_abbreviation(old_abbr), task_assessment_resources())
    end
  end

  def docker_image_name_tag
    return nil if overseer_image.nil?

    overseer_image.tag
  end

  def glob_for_upload_requirement(idx)
    "#{idx.to_s.rjust(3, '0')}-#{upload_requirements[idx]['type']}.*"
  end

  # Validate the format of the upload requirements
  def check_upload_requirements_format
    json_data = self.upload_requirements
    return if json_data.nil?

    # ensure we have a structure that is : [ { "key": "...", "name": "...", "type": "...", "tii_check": "...", "tii_pct": "..."}, { ... } ]
    unless json_data.class == Array
      errors.add(:upload_requirements, 'is not in a valid format! Should be [ { "key": "...", "name": "...", "type": "...", "tii_check": "...", "tii_pct": "..."}, { ... } ]. Did not contain array.')
      return
    end

    # Checking each upload requirement - i used to index files and for user errors
    i = 0
    for req in json_data do
      # Each requirement is a json object
      unless req.class == Hash
        errors.add(:upload_requirements, "is not in a valid format! Should be [ { \"key\": \"...\", \"name\": \"...\", \"type\": \"...\", \"tii_check\": \"...\", \"tii_pct\": \"...\"}, { ... } ]. Array did not contain hashes for item #{i + 1}..")
        return
      end

      # Check we have the keys we need
      if (!req.key? 'key') || (!req.key? 'name') || (!req.key? 'type')
        errors.add(:upload_requirements, "is not in a valid format! Must contain [ { \"key\": \"...\", \"name\": \"...\", \"type\": \"...\"}, { ... } ]. Missing a key for item #{i + 1}.")
        return
      end

      # Check keys only contain key, type, name, tii_check, and tii_pct
      unless req.keys.excluding('key', 'type', 'name', 'tii_check', 'tii_pct').empty?
        errors.add(:upload_requirements, "has additional values for item #{i + 1} --> #{req.keys.join(' ')}.")
      end

      i += 1
    end
  end

  def number_of_uploaded_files
    upload_requirements.length
  end

  def number_of_documents
    upload_requirements.map{|req| req['type'] == 'document' ? 1 : 0}.inject(:+) || 0
  end

  # Returns true if the uploaded file is a document
  def is_document?(idx)
    return false unless idx >= 0 && idx < upload_requirements.length
    upload_requirements[idx]['type'] == 'document'
  end

  # Return the type for the upload at the given index
  # @param idx the index of the upload requirement
  def type_for_upload(idx)
    return nil unless idx >= 0 && idx < upload_requirements.length
    upload_requirements[idx]['type']
  end

  def self.to_csv(task_definitions)
    CSV.generate() do |csv|
      csv << csv_columns
      task_definitions.each do |task_definition|
        csv << task_definition.to_csv_row
      end
    end
  end

  def start_week
    unit.week_number(start_date)
  end

  def start_day
    Date::ABBR_DAYNAMES[start_date.wday]
  end

  def start_week_and_day= value
    week, day = value
    self.start_date = unit.date_for_week_and_day(week, day)
  end

  def target_week
    unit.week_number(target_date)
  end

  def target_day
    Date::ABBR_DAYNAMES[target_date.wday]
  end

  def target_week_and_day= value
    week, day = value
    self.target_date = unit.date_for_week_and_day(week, day)
  end

  # Override due date to return either the final date of the unit, or the set due date
  def due_date
    return self['due_date'] if self['due_date'].present?

    return unit.end_date # TODO: use nil as default to improve performance
  end

  def due_week
    if due_date.present?
      unit.week_number(due_date)
    else
      ''
    end
  end

  def due_week_and_day= value
    week, day = value
    self.due_date = unit.date_for_week_and_day(week, day)
  end

  def due_day
    if due_date
      Date::ABBR_DAYNAMES[due_date.wday]
    else
      ''
    end
  end

  # Update all task dates by date_diff
  def propogate_date_changes date_diff
    self.start_date += date_diff
    self.target_date += date_diff
    self.due_date += date_diff unless self.due_date.nil?
    self.save!
  end

  def to_csv_row
    TaskDefinition.csv_columns
                  .reject { |col| [:start_week, :start_day, :target_week, :target_day, :due_week, :due_day, :upload_requirements, :group_set, :tutorial_stream].include? col }
                  .map { |column| attributes[column.to_s] } +
      [
        group_set.nil? ? "" : group_set.name,
        upload_requirements.to_s,
        start_week,
        start_day,
        target_week,
        target_day,
        due_week,
        due_day,
        tutorial_stream.present? ? tutorial_stream.abbreviation : nil
      ]
    # [target_date.strftime('%d-%m-%Y')] +
    # [ self['due_date'].nil? ? '' : due_date.strftime('%d-%m-%Y')]
  end

  def self.csv_columns
    [:name, :abbreviation, :description, :weighting, :target_grade, :restrict_status_updates, :max_quality_pts, :is_graded, :plagiarism_warn_pct, :group_set, :upload_requirements, :start_week, :start_day, :target_week, :target_day, :due_week, :due_day, :tutorial_stream]
  end

  def self.task_def_for_csv_row(unit, row)
    return [nil, false, 'Abbreviation and name cannot be empty.'] if row[:abbreviation].nil? || row[:name].nil? || row[:abbreviation].empty? || row[:name].empty?

    new_task = false
    abbreviation = row[:abbreviation].strip
    name = row[:name].strip
    tutorial_stream = unit.tutorial_streams.find_by_abbr_or_name("#{row[:tutorial_stream]}".strip)
    target_date = unit.date_for_week_and_day row[:target_week].to_i, "#{row[:target_day]}".strip
    return [nil, false, "Unable to determine target date for #{abbreviation} -- need week number, and day short text eg. 'Wed'"] if target_date.nil?

    start_date = unit.date_for_week_and_day row[:start_week].to_i, "#{row[:start_day]}".strip
    return [nil, false, "Unable to determine start date for #{abbreviation} -- need week number, and day short text eg. 'Wed'"] if start_date.nil?

    due_date = unit.date_for_week_and_day row[:due_week].to_i, "#{row[:due_day]}".strip

    result = TaskDefinition.find_by(unit_id: unit.id, abbreviation: abbreviation)

    result = TaskDefinition.find_by(unit_id: unit.id, name: name) if result.nil?

    if result.nil?
      # Remember creation triggers project task updates... so need correct weight
      result = TaskDefinition.find_or_create_by(unit_id: unit.id, tutorial_stream: tutorial_stream, name: name, abbreviation: abbreviation) do |td|
        td.target_date = target_date
        td.start_date = start_date
        td.weighting = row[:weighting].to_i
      end
      new_task = true
    end

    result.name                        = name
    result.unit_id                     = unit.id
    result.abbreviation                = abbreviation
    result.description                 = "#{row[:description]}".strip
    result.weighting                   = row[:weighting].to_i
    result.target_grade                = row[:target_grade].to_i
    result.restrict_status_updates     = %w(Yes y Y yes true TRUE 1).include? "#{row[:restrict_status_updates]}".strip
    result.max_quality_pts             = row[:max_quality_pts].to_i
    result.is_graded                   = %w(Yes y Y yes true TRUE 1).include? "#{row[:is_graded]}".strip
    result.start_date                  = start_date
    result.target_date                 = target_date
    result.upload_requirements         = JSON.parse(row[:upload_requirements]) unless row[:upload_requirements].nil?
    result.due_date                    = due_date

    result.plagiarism_warn_pct         = row[:plagiarism_warn_pct].to_i

    if row[:group_set].present?
      result.group_set = unit.group_sets.where(name: row[:group_set]).first
    end

    if row[:tutorial_stream].present?
      result.tutorial_stream = unit.tutorial_streams.where(abbreviation: row[:tutorial_stream]).first
    end

    if result.valid? && (row[:group_set].blank? || result.group_set.present?)
      begin
        result.save
      rescue
        result.destroy
        return [nil, false, 'Failed to save definition due to data error.']
      end
    else
      # delete the task if it was new
      result.destroy if new_task
      if result.group_set.nil? && row[:group_set].present?
        return [nil, false, "Unable to find groupset with name #{row[:group_set]} in unit."]
      else
        return [nil, false, result.errors.full_messages.join('. ')]
      end
    end

    [result, new_task, new_task ? "Added new task definition #{result.abbreviation}." : "Updated existing task #{result.abbreviation}"]
  end

  def is_group_task?
    !group_set.nil?
  end

  def has_task_resources?
    File.exist? task_resources
  end

  def has_task_assessment_resources?
    File.exist? task_assessment_resources
  end

  def has_task_sheet?
    File.exist? task_sheet
  end

  def is_graded?
    is_graded
  end

  def has_stars?
    max_quality_pts > 0
  end

  def add_task_sheet(file)
    FileUtils.mv file, task_sheet
  end

  def remove_task_sheet()
    if has_task_sheet?
      FileUtils.rm task_sheet
    end
  end

  # Move task resources into place
  def add_task_resources(file, copy: false)
    if copy
      FileUtils.cp file, task_resources
    else
      FileUtils.mv file, task_resources
    end

    # If TII is enabled, then we need to great group attachments
    if tii_checks?
      send_group_attachments_to_tii
    end
  end

  def remove_task_resources()
    if has_task_resources?
      FileUtils.rm task_resources

      tii_group_attachments.destroy_all if tii_checks?
    end
  end

  def add_task_assessment_resources(file)
    FileUtils.mv file, task_assessment_resources
    # TODO: Use FACL instead in future.
    `chmod 755 #{task_assessment_resources}`
  end

  def remove_task_assessment_resources()
    if has_task_assessment_resources?
      FileUtils.rm task_assessment_resources
    end
  end

  # Get the path to the task sheet - using the current abbreviation
  def task_sheet
    task_sheet_with_abbreviation(abbreviation)
  end

  def task_resources
    task_resources_with_abbreviation(abbreviation)
  end

  def task_assessment_resources
    task_assessment_resources_with_abbreviation(abbreviation)
  end

  def related_tasks_with_files(consolidate_groups = true)
    tasks_with_files = tasks.select(&:has_pdf)

    if is_group_task? && consolidate_groups
      # group task so only select one member of each group
      seen_groups = []

      tasks_with_files = tasks_with_files.select do |t|
        if t.group.nil?
          result = false
        else
          result = !seen_groups.include?(t.group)
          seen_groups << t.group if result
        end
        result
      end
    end

    tasks_with_files
  end

  # Read a file from the task definition resources.
  #
  # @param filename [String] The name of the file to read from the zipfile.
  # @return [String] The contents of the file, or nil if the file does not exist.
  def read_file_from_resources(filename)
    return nil unless has_task_resources?

    Zip::File.open(task_resources) do |zip_file|
      entry = zip_file.glob(filename).first
      return entry.get_input_stream.read if entry
    end

    nil
  end

  private

  def delete_associated_files()
    remove_task_sheet()
    remove_task_resources()
    remove_task_assessment_resources()
  end

  # Calculate the path to the task sheet using the provided abbreviation
  # This allows the path to be calculated on abbreviation change to allow files to
  # be moved
  def task_sheet_with_abbreviation(abbr)
    task_path = FileHelper.task_file_dir_for_unit unit, create = true

    result_with_sanitised_path = "#{task_path}#{FileHelper.sanitized_path(abbr)}.pdf"
    result_with_sanitised_file = "#{task_path}#{FileHelper.sanitized_filename(abbr)}.pdf"

    if File.exist? result_with_sanitised_path
      result_with_sanitised_path
    else
      result_with_sanitised_file
    end
  end

  # Calculate the path to the task sheet using the provided abbreviation
  # This allows the path to be calculated on abbreviation change to allow files to
  # be moved
  def task_resources_with_abbreviation(abbr)
    task_path = FileHelper.task_file_dir_for_unit unit, create = true

    result_with_sanitised_path = "#{task_path}#{FileHelper.sanitized_path(abbr)}.zip"
    result_with_sanitised_file = "#{task_path}#{FileHelper.sanitized_filename(abbr)}.zip"

    if File.exist? result_with_sanitised_path
      result_with_sanitised_path
    else
      result_with_sanitised_file
    end
  end

  def task_assessment_resources_with_abbreviation(abbr)
    task_path = FileHelper.task_file_dir_for_unit unit, create = true

    result_with_sanitised_path = "#{task_path}#{FileHelper.sanitized_path(abbr)}-assessment.zip"
    result_with_sanitised_file = "#{task_path}#{FileHelper.sanitized_filename(abbr)}-assessment.zip"

    if File.exist? result_with_sanitised_path
      result_with_sanitised_path
    else
      result_with_sanitised_file
    end
  end
end
