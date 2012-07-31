class TeamMembership < ActiveRecord::Base
	
  # Model associations
  belongs_to :user		# Foreign key
  has_one 	 :project, :dependent => :destroy  # Foreign key
  belongs_to :team 		# Foreign key

end