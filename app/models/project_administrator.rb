class ProjectAdministrator < ActiveRecord::Base
  attr_accessible :project_template_id, :user_id
  
  # Model associations
  belongs_to :project_template	# Foreign key
  belongs_to :user				# Foreign key

end
