class TutorFeedbackScore < ApplicationRecord
  belongs_to :unit_role
  belongs_to :task_definition
end
