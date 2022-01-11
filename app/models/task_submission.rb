class TaskSubmission < ApplicationRecord
  belongs_to :task, optional: false
  belongs_to :assessor, class_name: 'User', foreign_key: 'assessor_id', optional: true
end
