class Task < ActiveRecord::Base
	attr_accessible :description, :name, :recommended_completion_date, :required, :weighting

	# Model associations
	belongs_to :project		# Foreign key

	has_many :task_instances
end
