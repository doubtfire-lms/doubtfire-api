class ProjectConvenor < ActiveRecord::Base
  attr_accessible :unit_id, :user_id

  # Model associations
  belongs_to :unit	# Foreign key
  belongs_to :user				# Foreign key

end
