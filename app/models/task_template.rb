class TaskTemplate < ActiveRecord::Base
	attr_accessible :unit_id, :name, :abbreviation, :description, :target_date, :required, :weighting
	
	# Model associations
	belongs_to :unit			   # Foreign key
	has_many :tasks, :dependent => :destroy    # Destroying a task template will also nuke any instances

	# Model validations/constraints
	validates_uniqueness_of :name, :scope => :unit_id		# Task template names within a project template must be unique

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

  def self.to_csv(task_templates, options = {})
    CSV.generate(options) do |csv|
      csv << csv_columns
      task_templates.each do |task_template|
        csv << task_template.to_csv_row
      end
    end
  end

  def to_csv_row
    TaskTemplate.csv_columns.reject{|col| col == :target_date }.map{|column| attributes[column.to_s] } + [target_date.strftime('%d-%m-%Y')]
  end

  def self.csv_columns
    [:name, :abbreviation, :description, :weighting, :required, :target_date]
  end
end