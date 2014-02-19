class ProjectConvenor < ActiveRecord::Base
  # Model associations
  belongs_to :unit	# Foreign key
  belongs_to :user  # Foreign key
end
