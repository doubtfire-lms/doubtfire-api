class TeamMembership < ActiveRecord::Base
  # Model associations
  has_one :user			# Foreign key
  has_one :project_membership     # Foreign key
  belongs_to :team 		# Foreign key
end