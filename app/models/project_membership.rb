class ProjectMembership < ActiveRecord::Base
  	attr_accessible :project_role

  	# Model associations
  	belongs_to :team				# Foreign key
 	belongs_to :project_status		# Foreign key
  	belongs_to :project 			# Foreign key

  	has_many :task_instances
end
