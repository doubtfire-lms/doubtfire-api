class TaskStatus < ActiveRecord::Base
	# Model associations
	has_many :tasks
end