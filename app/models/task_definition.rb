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
  validate :upload_requirements, :check_upload_requirements_format
  validates :plagiarism_checks, length: { maximum: 4095, allow_blank: true }
  validate :plagiarism_checks, :check_plagiarism_format
  validates :description, length: { maximum: 4095, allow_blank: true }

  after_update do |_td|
    clear_related_plagiarism if plagiarism_checks.empty? && has_plagiarism?
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
                  .reject { |col| [:start_week, :start_day, :target_week, :target_day, :due_week, :due_day, :upload_requirements, :group_set].include? col }
                  .map { |column| attributes[column.to_s] } +
      [ group_set.nil? ? "" : group_set.name, 
        upload_requirements.to_json,
        start_week, 
        start_day, 
        target_week, 
        target_day, 
        due_week, 
        due_day 
      ]
    # [target_date.strftime('%d-%m-%Y')] +
    # [ self['due_date'].nil? ? '' : due_date.strftime('%d-%m-%Y')]
  end

  def self.csv_columns
    [:name, :abbreviation, :description, :weighting, :target_grade, :restrict_status_updates, :max_quality_pts, :is_graded, :plagiarism_warn_pct, :plagiarism_checks, :group_set, :upload_requirements, :start_week, :start_day, :target_week, :target_day, :due_week, :due_day]
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

    result.plagiarism_warn_pct         = row[:plagiarism_warn_pct]
    result.plagiarism_checks           = row[:plagiarism_checks]
    

    row[:group_set] = nil if row[:group_set].empty?
    result.group_set                   = unit.group_sets.where(name: row[:group_set]).first

    if result.valid? && (row[:group_set].nil? || !result.group_set.nil?)
      begin
        result.save
      rescue
        result.destroy
        return [nil, false, 'Failed to save definition due to data error.']
      end
    else
      if result.group_set.nil? && !row[:group_set].nil?
        return [nil, false, "Unable to find groupset with name #{row[:group_set]} in unit."]
      else
        return [nil, false, result.errors.full_messages.join('. ')]
      end
    end

    [result, new_task, new_task ? "Added new task definition #{result.abbreviation}." : "Updated existing task #{result.abbreviation}" ]
  end

  def is_group_task?
    !group_set.nil?
  end

  def has_task_resources?
    File.exist? unit.path_to_task_resources(self)
  end

  def has_task_pdf?
    File.exist? unit.path_to_task_pdf(self)
  end

  def is_graded?
    is_graded
  end

  def has_stars?
    max_quality_pts > 0
  end

  def add_task_sheet(file)
    FileUtils.mv file, unit.path_to_task_pdf(self)
  end

  def add_task_resources(file)
    FileUtils.mv file, unit.path_to_task_resources(self)
  end

  def task_sheet
    unit.path_to_task_pdf(self)
  end

  def task_resources
    unit.path_to_task_resources(self)
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
end
