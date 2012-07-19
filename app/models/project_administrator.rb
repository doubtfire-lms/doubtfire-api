class ProjectAdministrator < ActiveRecord::Base
  # attr_accessible :title, :body

  # Model associations
  belongs_to :project_template	# Foreign key
  belongs_to :user				# Foreign key

end
