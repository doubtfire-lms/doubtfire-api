class Team < ActiveRecord::Base
  	attr_accessible :meeting_location, :meeting_time

  	# Model associations
  	belongs_to :project		# Foreign key
  	belongs_to :user		# Foreign key
end
