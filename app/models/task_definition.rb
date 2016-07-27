require 'json'

class TaskDefinition < ActiveRecord::Base
  # Model associations
  belongs_to :unit # Foreign key
  belongs_to :group_set
  has_many :tasks, dependent:  :destroy    # Destroying a task definition will also nuke any instances
  has_many :group_submissions, dependent:  :destroy    # Destroying a task definition will also nuke any group submissions

  has_many :learning_outcome_task_links, dependent: :destroy # links to learning outcomes
  has_many :learning_outcomes, -> { where("learning_outcome_task_links.task_id is NULL") },  through: :learning_outcome_task_links # only link staff relations

  # Model validations/constraints
  validates_uniqueness_of :name, scope:  :unit_id  # task definition names within a unit must be unique
  validates_uniqueness_of :abbreviation, scope:  :unit_id   # task definition names within a unit must be unique

  validates :target_grade, inclusion: { in: 0..3, message: "%{value} is not a valid target grade" }
  validates :max_quality_pts, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10, message: "must be between 0 and 10" }

  after_create do |td|
    td.unit.update_project_stats
  end

  after_destroy do |td|
    td.unit.update_project_stats
  end

  after_update do |td|
    if plagiarism_checks.length == 0 && has_plagiarism?
      clear_related_plagiarism()
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
    if req.class == String
      # get the ruby objects from the json data
      json_data = JSON.parse(req)
    else
      # use the passed in objects
      json_data = req
    end

    # ensure we have a structure that is : [ { "key": "...", "type": "...", "pattern": "..."}, { ... } ]
    if not json_data.class == Array
      errors.add(:plagiarism_checks, "is not in a valid format! Should be [ { \"key\": \"...\", \"type\": \"...\", \"pattern\": \"...\"}, { ... } ]. Did not contain array.")
      return
    end

    i = 0
    for req in json_data do
      if not req.class == Hash
        errors.add(:plagiarism_checks, "is not in a valid format! Should be [ { \"key\": \"...\", \"type\": \"...\", \"pattern\": \"...\"}, { ... } ]. Array did not contain hashes for item #{i + 1}..")
        return
      end

      req.delete_if {|key, value| not ["key", "type", "pattern"].include? key }

      req["key"] = "check#{i}"

      if (not req.has_key? "key") or (not req.has_key? "type") or (not req.has_key? "pattern") then
        errors.add(:plagiarism_checks, "is not in a valid format! Should be [ { \"key\": \"...\", \"type\": \"...\", \"pattern\": \"...\"}, { ... } ]. Missing a key for item #{i + 1}.")
        return
      end

      i += 1
    end

    self['plagiarism_checks'] = JSON.unparse(json_data)
    if self['plagiarism_checks'].nil?
      self['plagiarism_checks'] = '[]'
    end
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
    if req.class == String
      # get the ruby objects from the json data
      json_data = JSON.parse(req)
    else
      # use the passed in objects
      json_data = req
    end

    # ensure we have a structure that is : [ { "key": "...", "name": "...", "type": "..."}, { ... } ]
    if not json_data.class == Array
      errors.add(:upload_requirements, "is not in a valid format! Should be [ { \"key\": \"...\", \"name\": \"...\", \"type\": \"...\"}, { ... } ]. Did not contain array.")
      return
    end

    i = 0
    for req in json_data do
      if not req.class == Hash
        errors.add(:upload_requirements, "is not in a valid format! Should be [ { \"key\": \"...\", \"name\": \"...\", \"type\": \"...\"}, { ... } ]. Array did not contain hashes for item #{i + 1}..")
        return
      end

      req.delete_if {|key, value| not ["key", "name", "type"].include? key }

      req["key"] = "file#{i}"

      if (not req.has_key? "key") or (not req.has_key? "name") or (not req.has_key? "type") then
        errors.add(:upload_requirements, "is not in a valid format! Should be [ { \"key\": \"...\", \"name\": \"...\", \"type\": \"...\"}, { ... } ]. Missing a key for item #{i + 1}.")
        return
      end

      i += 1
    end

    self['upload_requirements'] = JSON.unparse(json_data)
    if self['upload_requirements'].nil?
      self['upload_requirements'] = '[]'
    end
  end

  def has_plagiarism?()
    PlagiarismMatchLink.joins(:task).where("tasks.task_definition_id" => self.id).count > 0
  end

  def clear_related_plagiarism()
    # delete old plagiarism links
    logger.info "Deleting old links for task definition #{self.id} - #{self.abbreviation}"
    PlagiarismMatchLink.joins(:task).where("tasks.task_definition_id" => self.id).each do | plnk |
      begin
        PlagiarismMatchLink.find(plnk.id).destroy!
      rescue
      end
    end

    # Reset the tasks % similar
    logger.debug "Clearing old task percent similar"
    tasks.where("tasks.max_pct_similar > 0").each do |t|
      t.max_pct_similar = 0
      t.save
    end
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
    ((start_date - unit.start_date) / 1.weeks).floor
  end

  def start_day
    Date::ABBR_DAYNAMES[start_date.wday]
  end

  def target_week
    ((target_date - unit.start_date) / 1.weeks).floor
  end

  def target_day
    Date::ABBR_DAYNAMES[target_date.wday]
  end

  def due_week
    if due_date
      ((due_date - unit.start_date) / 1.weeks).floor
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
    TaskDefinition.csv_columns.
      reject{|col| [:start_week, :start_day, :target_week, :target_day, :due_week, :due_day, :upload_requirements].include? col }.
      map{|column| attributes[column.to_s] } +
      [ upload_requirements.to_json ] +
      [ start_week, start_day, target_week, target_day, due_week, due_day ]
      # [target_date.strftime('%d-%m-%Y')] +
      # [ self['due_date'].nil? ? '' : due_date.strftime('%d-%m-%Y')]
  end

  def self.csv_columns
    [:name, :abbreviation, :description, :weighting, :target_grade, :restrict_status_updates, :max_quality_pts, :is_graded, :upload_requirements, :start_week, :start_day, :target_week, :target_day, :due_week, :due_day]
  end

  def self.task_def_for_csv_row(unit, row)
    return [nil, false, "Abbreviation and name cannot be empty."] if row[:abbreviation].nil? || row[:name].nil? || row[:abbreviation].empty? || row[:name].empty?

    new_task = false
    abbreviation = row[:abbreviation].strip
    name = row[:name].strip
    target_date = unit.date_for_week_and_day row[:target_week].to_i, row[:target_day]
    return [nil, false, "Unable to determine target date for #{abbreviation} -- need week number, and day short text eg. 'Wed'"] if target_date.nil?

    start_date = unit.date_for_week_and_day row[:start_week].to_i, row[:start_day]
    return [nil, false, "Unable to determine start date for #{abbreviation} -- need week number, and day short text eg. 'Wed'"] if start_date.nil?

    due_date = unit.date_for_week_and_day row[:due_week].to_i, row[:due_day]

    result = TaskDefinition.find_by(unit_id: unit.id, abbreviation: abbreviation)

    if result.nil?
      result = TaskDefinition.find_by(unit_id: unit.id, name: name)
    end

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
    result.restrict_status_updates     = ["Yes", "y", "Y", "yes", "true", "TRUE", "1"].include? row[:restrict_status_updates]
    result.max_quality_pts             = row[:max_quality_pts].to_i
    result.is_graded                   = ["Yes", "y", "Y", "yes", "true", "TRUE", "1"].include? row[:is_graded]
    result.start_date                  = start_date
    result.target_date                 = target_date
    result.upload_requirements         = row[:upload_requirements]
    result.due_date                    = due_date

    if result.valid?
      begin
        result.save
      rescue
        result.destroy
        return [nil, false, "Failed to save definition due to data error."]
      end
    else
      return [nil, false, result.errors.join(". ")]
    end
    [result, new_task, new_task ? "Added new task definition #{result.abbreviation}." : "Updated existing task #{result.abbreviation}" ]
  end

  def is_group_task?
    not group_set.nil?
  end

  def has_task_resources?
    File.exists? unit.path_to_task_resources(self)
  end

  def has_task_pdf?
    File.exists? unit.path_to_task_pdf(self)
  end

  def add_task_sheet (file)
    FileUtils.mv file, unit.path_to_task_pdf(self)
  end

  def add_task_resources (file)
    FileUtils.mv file, unit.path_to_task_resources(self)
  end

  def task_sheet
    unit.path_to_task_pdf(self)
  end

  def task_resources
    unit.path_to_task_resources(self)
  end
end
