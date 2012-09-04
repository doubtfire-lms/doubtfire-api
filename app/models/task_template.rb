class TaskTemplate < ActiveRecord::Base
	attr_accessible :project_template_id, :description, :name, :target_date, :required, :weighting
	
	# Model associations
	belongs_to :project_template			   # Foreign key
	has_many :tasks, :dependent => :destroy    # Destroying a task template will also nuke any instances

	# Model validations/constraints
	validates_uniqueness_of :name, :scope => :project_template_id		# Task template names within a project template must be unique

  def status_distribution    
    {
      not_submitted: tasks.select{|task| task.task_status_id == 1 }.size,
      need_help:      tasks.select{|task| task.task_status_id == 4 }.size,
      working_on_it:  tasks.select{|task| task.task_status_id == 5 }.size,
      needs_fixing:   tasks.select{|task| task.task_status_id == 2 }.size,
      complete:       tasks.select{|task| task.task_status_id == 3 }.size
    }
  end
end