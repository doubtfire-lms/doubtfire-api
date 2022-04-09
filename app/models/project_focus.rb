class ProjectFocus < ApplicationRecord
  belongs_to :project, optional: false
  belongs_to :focus, optional: false
end
