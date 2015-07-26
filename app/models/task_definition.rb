require 'json'

class TaskDefinition < ActiveRecord::Base
	# Model associations
	belongs_to :unit			   # Foreign key
  belongs_to :group_set
	has_many :tasks, dependent:  :destroy    # Destroying a task definition will also nuke any instances

	# Model validations/constraints
	validates_uniqueness_of :name, scope:  :unit_id		# task definition names within a unit must be unique
  validates_uniqueness_of :abbreviation, scope:  :unit_id   # task definition names within a unit must be unique

  def status_distribution
    task_instances = tasks

    awaiting_signoff = task_instances.select{|task| task.awaiting_signoff? }

    task_instances = task_instances - awaiting_signoff
    {
      awaiting_signoff: awaiting_signoff.size,
      not_submitted:    task_instances.select{|task| task.task_status_id == 1 }.size,
      need_help:        task_instances.select{|task| task.task_status_id == 3 }.size,
      working_on_it:    task_instances.select{|task| task.task_status_id == 4 }.size,
      redo:             task_instances.select{|task| task.task_status_id == 7 }.size,
      fix_and_resubmit: task_instances.select{|task| task.task_status_id == 5 }.size,
      fix_and_include:  task_instances.select{|task| task.task_status_id == 6 }.size,
      complete:         task_instances.select{|task| task.task_status_id == 2 }.size
    }
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
      jsonData = JSON.parse(req)
    else
      # use the passed in objects
      jsonData = req
    end

    # ensure we have a structure that is : [ { "key": "...", "type": "...", "pattern": "..."}, { ... } ]
    if not jsonData.class == Array
      errors.add(:plagiarism_checks, "is not in a valid format! Should be [ { \"key\": \"...\", \"type\": \"...\", \"pattern\": \"...\"}, { ... } ]. Did not contain array.")
      return
    end

    i = 0
    for req in jsonData do
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

    self['plagiarism_checks'] = JSON.unparse(jsonData)
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
      jsonData = JSON.parse(req)
    else
      # use the passed in objects
      jsonData = req
    end

    # ensure we have a structure that is : [ { "key": "...", "name": "...", "type": "..."}, { ... } ]
    if not jsonData.class == Array
      errors.add(:upload_requirements, "is not in a valid format! Should be [ { \"key\": \"...\", \"name\": \"...\", \"type\": \"...\"}, { ... } ]. Did not contain array.")
      return
    end

    i = 0
    for req in jsonData do
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

    self['upload_requirements'] = JSON.unparse(jsonData)
    if self['upload_requirements'].nil?
      self['upload_requirements'] = '[]'
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

  def to_csv_row
    TaskDefinition.csv_columns.reject{|col| col == :target_date || col == :upload_requirements }.map{|column| attributes[column.to_s] } + [upload_requirements.to_json] + [target_date.strftime('%d-%m-%Y')]
  end

  def self.csv_columns
    [:name, :abbreviation, :description, :weighting, :required, :target_grade, :restrict_status_updates, :upload_requirements, :target_date]
  end

  def has_task_resources?
    File.exists? unit.path_to_task_resources(self)
  end

  def has_task_pdf?
    File.exists? unit.path_to_task_pdf(self)
  end
end