class TaskSubmission < ApplicationRecord
  belongs_to :task, optional: false
  belongs_to :assessor, class_name: 'User', optional: true
end
