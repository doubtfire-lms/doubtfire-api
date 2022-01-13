class TaskEngagement < ApplicationRecord
  belongs_to :task, optional: false
end
