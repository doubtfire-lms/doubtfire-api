class DiscussionPrompt < ApplicationRecord

  belongs_to :task_definition, optional: false
  belongs_to :project, optional: true
  belongs_to :created_by, class_name: 'User', optional: true

end
