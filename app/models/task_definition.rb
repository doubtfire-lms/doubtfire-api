require 'json'

class TaskDefinition < ApplicationRecord
  # Record triggers - before associations
  after_update do |_td|
    clear_related_plagiarism if plagiarism_checks.empty? && has_plagiarism?
  end

  before_destroy :delete_associated_files

  after_update :move_files_on_abbreviation_change, if: :saved_change_to_abbreviation?
  after_update :remove_old_group_submissions, if: :has_removed_group?

  # Model associations
  belongs_to :unit, optional: false # Foreign key
  belongs_to :group_set, optional: true
  belongs_to :tutorial_stream, optional: true
  belongs_to :overseer_image, optional: true

  has_many :tasks, dependent:  :destroy # Destroying a task definition will also nuke any instances
  has_many :group_submissions, dependent: :destroy # Destroying a task definition will also nuke any group submissions
  has_many :learning_outcome_task_links, dependent: :destroy # links to learning outcomes
  has_many :learning_outcomes, -> { where('learning_outcome_task_links.task_id is NULL') }, through: :learning_outcome_task_links # only link staff relations

  # Model validations/constraints
  validates :name, uniqueness: { scope:  :unit_id } # task definition names within a unit must be unique
  validates :abbreviation, uniqueness: { scope: :unit_id } # task definition names within a unit must be unique

  validates :target_grade, inclusion: { in: GradeHelper::RANGE, message: '%{value} is not a valid target grade' }
  validates :max_quality_pts, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10, message: 'must be between 0 and 10' }

  validates :upload_requirements, length: { maximum: 4095, allow_blank: true }
  validate :upload_requirements, :check_upload_requirements_format
  validates :plagiarism_checks, length: { maximum: 4095, allow_blank: true }
  validate :plagiarism_checks, :check_plagiarism_format
  validates :description, length: { maximum: 4095, allow_blank: true }

  validate :ensure_no_submissions, if: :will_save_change_to_group_set_id?
  validate :unit_must_be_same
  validate :tutorial_stream_present?

  validates :weighting, presence: true

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
      FileUtils.cp(task_resources, new_td.task_resources)
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

  def plagiarism_checks
    # Read the JSON string in upload_requirements and convert into ruby objects
    if self['plagiarism_checks']
      begin
        # Parse into ruby objects
        JSON.parse(self['plagiarism_checks'])
      rescue
        # If this fails return the string - validation should then invalidate this object
        self['plagiarism_checks']
      end
    else
      # If it was empty then return an empty array
      JSON.parse('[]')
    end
  end

  def check_plagiarism_format()
    json_data = self.plagiarism_checks

    # ensure we have a structure that is : [ { "key": "...", "type": "...", "pattern": "..."}, { ... } ]
    unless json_data.class == Array
      errors.add(:plagiarism_checks, 'is not in a valid format! Should be [ { "key": "...", "type": "...", "pattern": "..."}, { ... } ]. Did not contain array.')
      return
    end

    # Loop through checks in the array
    i = 0
    for req in json_data do
      # They must be json objects
      unless req.class == Hash
        errors.add(:plagiarism_checks, "is not in a valid format! Should be [ { \"key\": \"...\", \"type\": \"...\", \"pattern\": \"...\"}, { ... } ]. Array did not contain hashes for item #{i + 1}..")
        return
      end

      # They must have these keys...
      if (!req.key? 'key') || (!req.key? 'type') || (!req.key? 'pattern')
        errors.add(:plagiarism_checks, "is not in a valid format! Should be [ { \"key\": \"...\", \"type\": \"...\", \"pattern\": \"...\"}, { ... } ]. Missing a key for item #{i + 1}.")
        return
      end

      # Validate the type (MOSS now, Turnitin later)
      if (!req['type'].match(/^moss /))
        errors.add(:plagiarism_checks, "does not have a valid type.")
        return
      end

      # Check patter to exclude any path separators
      if (req['pattern'].match(/(\/)|([.][.])/))
        errors.add(:plagiarism_checks, " pattern contains invalid characters.")
        return
      end

      # Move to the next check
      i += 1
    end
  end

  def plagiarism_checks=(req)
    begin
      json_data = if req.class == String
                    # get the ruby objects from the json data
                    JSON.parse(req)
                  else
                    # use the passed in objects
                    req
                  end
    rescue
      # Not valid json!
      # Save what we have - validation should raise an error
      self['plagiarism_checks'] = req
      return
    end

    # Cant process unless it is an array...
    unless json_data.class == Array
      # Save what we have - validation should raise an error
      self['plagiarism_checks'] = req
      return
    end

    # Loop through all items in json array
    i = 0
    for req in json_data do
      unless req.class == Hash
        # Cant process if it is not an object - leave for validation to check
        next
      end

      # Delete any other keys
      req.delete_if { |key, _value| !%w(key type pattern).include? key }

      # Add in check key
      req['key'] = "check#{i}"

      i += 1
    end

    # Save
    self['plagiarism_checks'] = JSON.unparse(json_data)
    self['plagiarism_checks'] = '[]' if self['plagiarism_checks'].nil?
  end

  def upload_requirements
    # Read the JSON string in upload_requirements and convert into ruby objects
    if self['upload_requirements']
      begin
        # convert to ruby objects
        JSON.parse(self['upload_requirements'])
      rescue
        # Its not valid json - so return the string and validation should fail this object
        self['upload_requirements']
      end
    else
      # Return an empty array as no requirements
      JSON.parse('[]')
    end
  end

  # Validate the format of the upload requirements
  def check_upload_requirements_format()
    json_data = self.upload_requirements

    # ensure we have a structure that is : [ { "key": "...", "name": "...", "type": "..."}, { ... } ]
    unless json_data.class == Array
      errors.add(:upload_requirements, 'is not in a valid format! Should be [ { "key": "...", "name": "...", "type": "..."}, { ... } ]. Did not contain array.')
      return
    end

    # Checking each upload requirement - i used to index files and for user errors
    i = 0
    for req in json_data do
      # Each requirement is a json object
      unless req.class == Hash
        errors.add(:upload_requirements, "is not in a valid format! Should be [ { \"key\": \"...\", \"name\": \"...\", \"type\": \"...\"}, { ... } ]. Array did not contain hashes for item #{i + 1}..")
        return
      end

      # Check we have the keys we need
      if (!req.key? 'key') || (!req.key? 'name') || (!req.key? 'type')
        errors.add(:upload_requirements, "is not in a valid format! Should be [ { \"key\": \"...\", \"name\": \"...\", \"type\": \"...\"}, { ... } ]. Missing a key for item #{i + 1}.")
        return
      end

      i += 1
    end
  end

  def upload_requirements=(req)
    begin
      json_data = if req.class == String
                    # get the ruby objects from the json data
                    JSON.parse(req)
                  else
                    # use the passed in objects
                    req
                  end
    rescue
      # Not valid json
      # Save what we have - validation should raise an error
      self['upload_requirements'] = req
      return
    end

    # cant process unless it is an array
    unless json_data.class == Array
      self['upload_requirements'] = req
      return
    end

    # Checking each upload requirement - i used to index files and for user errors
    i = 0
    for req in json_data do
      # Cant process unless it is a hash
      unless req.class == Hash
        next
      end

      # Delete all other keys...
      req.delete_if { |key, _value| !%w(key name type).include? key }

      # Set the 'key' to be the matching file
      req['key'] = "file#{i}"

      i += 1
    end

    # Save
    self['upload_requirements'] = JSON.unparse(json_data)
    self['upload_requirements'] = '[]' if self['upload_requirements'].nil?
  end

  def has_plagiarism?
    PlagiarismMatchLink.joins(:task).where('tasks.task_definition_id' => id).count > 0
  end

  def clear_related_plagiarism
    # delete old plagiarism links
    logger.info "Deleting old links for task definition #{id} - #{abbreviation}"
    PlagiarismMatchLink.joins(:task).where('tasks.task_definition_id' => id).find_each do |plnk|
      begin
        PlagiarismMatchLink.find(plnk.id).destroy!
      rescue
      end
    end
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
                  .reject { |col| [:start_week, :start_day, :target_week, :target_day, :due_week, :due_day, :upload_requirements, :plagiarism_checks, :group_set, :tutorial_stream].include? col }
                  .map { |column| attributes[column.to_s] } +
      [
        plagiarism_checks.to_json,
        group_set.nil? ? "" : group_set.name,
        upload_requirements.to_json,
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
    [:name, :abbreviation, :description, :weighting, :target_grade, :restrict_status_updates, :max_quality_pts, :is_graded, :plagiarism_warn_pct, :plagiarism_checks, :group_set, :upload_requirements, :start_week, :start_day, :target_week, :target_day, :due_week, :due_day, :tutorial_stream]
  end

  def self.task_def_for_csv_row(unit, row)
    return [nil, false, 'Abbreviation and name cannot be empty.'] if row[:abbreviation].nil? || row[:name].nil? || row[:abbreviation].empty? || row[:name].empty?

    new_task = false
    abbreviation = row[:abbreviation].strip
    name = row[:name].strip
    tutorial_stream = unit.tutorial_streams.find_by('abbreviation = :name OR name = :name', name: "#{row[:tutorial_stream]}".strip)
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
    result.upload_requirements         = row[:upload_requirements]
    result.due_date                    = due_date

    result.plagiarism_warn_pct         = row[:plagiarism_warn_pct].to_i
    result.plagiarism_checks           = row[:plagiarism_checks]

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

  def add_task_resources(file)
    FileUtils.mv file, task_resources
  end

  def remove_task_resources()
    if has_task_resources?
      FileUtils.rm task_resources
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
