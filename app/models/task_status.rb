class TaskStatus < ActiveRecord::Base
	attr_accessible :description, :name

	# Model associations
	has_many :task_instances
end
