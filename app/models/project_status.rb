class ProjectStatus < ActiveRecord::Base
	attr_accessible :health

	# Model associations
	has_many :project_memberships
end
