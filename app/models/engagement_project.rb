class EngagementProject < ApplicationRecord
  belongs_to :engagement, optional: false, inverse_of: :engagement_projects
  belongs_to :project, optional: false, inverse_of: :engagement_projects

  validates :project_id, uniqueness: { scope: :engagement_id }
end
