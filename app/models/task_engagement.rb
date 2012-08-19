class TaskEngagement < ActiveRecord::Base
  belongs_to :task
  attr_accessible :task, :engagement, :engagement_time
end
