require 'json'

class TaskDefinition < ActiveRecord::Base
  # Model associations
  belongs_to :unit # Foreign key
  belongs_to :group_set
  has_many :tasks, dependent:  :destroy # Destroying a task definition will also nuke any instances
  has_many :group_submissions, dependent: :destroy # Destroying a task definition will also nuke any group submissions

  has_many :learning_outcome_task_links, dependent: :destroy # links to learning outcomes
  has_many :learning_outcomes, -> { where('learning_outcome_task_links.task_id is NULL') }, through: :learning_outcome_task_links # only link staff relations

  # Model validations/constraints
  validates :name, uniqueness: { scope:  :unit_id } # task definition names within a unit must be unique
  validates :abbreviation, uniqueness: { scope: :unit_id } # task definition names within a unit must be unique

  validates :target_grade, inclusion: { in: 0..3, message: '%{value} is not a valid target grade' }
  validates :max_quality_pts, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10, message: 'must be between 0 and 10' }

  validates :upload_requirements, length: { maximum: 4095, allow_blank: true }
  validates :plagiarism_checks, length: { maximum: 4095, allow_blank: true }
  validates :description, length: { maximum: 4095, allow_blank: true }

  after_update do |_td|
    clear_related_plagiarism if plagiarism_checks.empty? && has_plagiarism?
  end

  after_update :move_files_on_abbreviation_change, if: :abbreviation_changed?

  def move_files_on_abbreviation_change
    if File.exists? task_sheet_with_abbreviation(abbreviation_was)
      FileUtils.mv(task_sheet_with_abbreviation(abbreviation_was), task_sheet())
    end

    if File.exists? task_resources_with_abbreviation(abbreviation_was)
      FileUtils.mv(task_resources_with_abbreviation(abbreviation_was), task_resources())
    end
  end

  def plagiarism_checks
    # Read the JSON string in upload_requirements and convert into ruby objects
    if self['plagiarism_checks']
      JSON.parse(self['plagiarism_checks'])
    else
      JSON.parse('[]')
    end
  end

  def plagiarism_checks=(req)
    json_data = if req.class == String
                  # get the ruby objects from the json data
                  JSON.parse(req)
                else
                  # use the passed in objects
                  req
                end

    # ensure we have a structure that is : [ { "key": "...", "type": "...", "pattern": "..."}, { ... } ]
    unless json_data.class == Array
      errors.add(:plagiarism_checks, 'is not in a valid format! Should be [ { "key": "...", "type": "...", "pattern": "..."}, { ... } ]. Did not contain array.')
      return
    end

    i = 0
    for req in json_data do
      unless req.class == Hash
        errors.add(:plagiarism_checks, "is not in a valid format! Should be [ { \"key\": \"...\", \"type\": \"...\", \"pattern\": \"...\"}, { ... } ]. Array did not contain hashes for item #{i + 1}..")
        return
      end

      req.delete_if { |key, _value| !%w(key type pattern).include? key }

      req['key'] = "check#{i}"

      if (!req.key? 'key') || (!req.key? 'type') || (!req.key? 'pattern')
        errors.add(:plagiarism_checks, "is not in a valid format! Should be [ { \"key\": \"...\", \"type\": \"...\", \"pattern\": \"...\"}, { ... } ]. Missing a key for item #{i + 1}.")
        return
      end

      i += 1
    end

    self['plagiarism_checks'] = JSON.unparse(json_data)
    self['plagiarism_checks'] = '[]' if self['plagiarism_checks'].nil?
  end

  def upload_requirements
    # Read the JSON string in upload_requirements and convert into ruby objects
    if self['upload_requirements']
      JSON.parse(self['upload_requirements'])
    else
      JSON.parse('[]')
    end
  end

  def upload_requirements=(req)
    json_data = if req.class == String
                  # get the ruby objects from the json data
                  JSON.parse(req)
                else
                  # use the passed in objects
                  req
                end

    # ensure we have a structure that is : [ { "key": "...", "name": "...", "type": "..."}, { ... } ]
    unless json_data.class == Array
      errors.add(:upload_requirements, 'is not in a valid format! Should be [ { "key": "...", "name": "...", "type": "..."}, { ... } ]. Did not contain array.')
      return
    end

    i = 0
    for req in json_data do
      unless req.class == Hash
        errors.add(:upload_requirements, "is not in a valid format! Should be [ { \"key\": \"...\", \"name\": \"...\", \"type\": \"...\"}, { ... } ]. Array did not contain hashes for item #{i + 1}..")
        return
      end

      req.delete_if { |key, _value| !%w(key name type).include? key }

      req['key'] = "file#{i}"

      if (!req.key? 'key') || (!req.key? 'name') || (!req.key? 'type')
        errors.add(:upload_requirements, "is not in a valid format! Should be [ { \"key\": \"...\", \"name\": \"...\", \"type\": \"...\"}, { ... } ]. Missing a key for item #{i + 1}.")
        return
      end

      i += 1
    end

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

    # TODO: Remove once max_pct_similar is deleted
    # # Reset the tasks % similar
    # logger.debug "Clearing old task percent similar"
    # tasks.where("tasks.max_pct_similar > 0").each do |t|
    #   t.max_pct_similar = 0
    #   t.save
    # end
  end

  def self.to_csv(task_definitions, options = {})
    CSV.generate(options) do |csv|
      csv << csv_columns
      task_definitions.each do |task_definition|
        csv << task_definition.to_csv_row
      end
    end
  end

  def start_week
    ((start_date - unit.start_date) / 1.week).floor
  end

  def start_day
    Date::ABBR_DAYNAMES[start_date.wday]
  end

  def target_week
    ((target_date - unit.start_date) / 1.week).floor
  end

  def target_day
    Date::ABBR_DAYNAMES[target_date.wday]
  end

  # Override due date to return either the final date of the unit, or the set due date
  def due_date
    return self['due_date'] if self['due_date'].present?
    return unit.end_date
  end

  def due_week
    if due_date
      ((due_date - unit.start_date) / 1.week).floor
    else
      ''
    end
  end

  def due_day
    if due_date
      Date::ABBR_DAYNAMES[due_date.wday]
    else
      ''
    end
  end

  def to_csv_row
    TaskDefinition.csv_columns
                  .reject { |col| [:start_week, :start_day, :target_week, :target_day, :due_week, :due_day, :upload_requirements].include? col }
                  .map { |column| attributes[column.to_s] } +
      [ upload_requirements.to_json ] +
      [ start_week, start_day, target_week, target_day, due_week, due_day ]
    # [target_date.strftime('%d-%m-%Y')] +
    # [ self['due_date'].nil? ? '' : due_date.strftime('%d-%m-%Y')]
  end

  def self.csv_columns
    [:name, :abbreviation, :description, :weighting, :target_grade, :restrict_status_updates, :max_quality_pts, :is_graded, :upload_requirements, :start_week, :start_day, :target_week, :target_day, :due_week, :due_day]
  end

  def self.task_def_for_csv_row(unit, row)
    return [nil, false, 'Abbreviation and name cannot be empty.'] if row[:abbreviation].nil? || row[:name].nil? || row[:abbreviation].empty? || row[:name].empty?

    new_task = false
    abbreviation = row[:abbreviation].strip
    name = row[:name].strip
    target_date = unit.date_for_week_and_day row[:target_week].to_i, row[:target_day]
    return [nil, false, "Unable to determine target date for #{abbreviation} -- need week number, and day short text eg. 'Wed'"] if target_date.nil?

    start_date = unit.date_for_week_and_day row[:start_week].to_i, row[:start_day]
    return [nil, false, "Unable to determine start date for #{abbreviation} -- need week number, and day short text eg. 'Wed'"] if start_date.nil?

    due_date = unit.date_for_week_and_day row[:due_week].to_i, row[:due_day]

    result = TaskDefinition.find_by(unit_id: unit.id, abbreviation: abbreviation)

    result = TaskDefinition.find_by(unit_id: unit.id, name: name) if result.nil?

    if result.nil?
      # Remember creation triggers project task updates... so need correct weight
      result = TaskDefinition.find_or_create_by(unit_id: unit.id, name: name, abbreviation: abbreviation) do |td|
        td.target_date = target_date
        td.start_date = start_date
        td.weighting = row[:weighting].to_i
      end
      new_task = true
    end

    result.name                        = name
    result.unit_id                     = unit.id
    result.abbreviation                = abbreviation
    result.description                 = row[:description]
    result.weighting                   = row[:weighting].to_i
    result.target_grade                = row[:target_grade].to_i
    result.restrict_status_updates     = %w(Yes y Y yes true TRUE 1).include? row[:restrict_status_updates]
    result.max_quality_pts             = row[:max_quality_pts].to_i
    result.is_graded                   = %w(Yes y Y yes true TRUE 1).include? row[:is_graded]
    result.start_date                  = start_date
    result.target_date                 = target_date
    result.upload_requirements         = row[:upload_requirements]
    result.due_date                    = due_date

    if result.valid?
      begin
        result.save
      rescue
        result.destroy
        return [nil, false, 'Failed to save definition due to data error.']
      end
    else
      return [nil, false, result.errors.join('. ')]
    end
    [result, new_task, new_task ? "Added new task definition #{result.abbreviation}." : "Updated existing task #{result.abbreviation}" ]
  end

  def is_group_task?
    !group_set.nil?
  end

  def has_task_resources?
    File.exist? task_resources
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

  def add_task_resources(file)
    FileUtils.mv file, task_resources
  end

  # Get the path to the task sheet - using the current abbreviation
  def task_sheet
    task_sheet_with_abbreviation(abbreviation)
  end

  def task_resources
    task_resources_with_abbreviation(abbreviation)
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
end
