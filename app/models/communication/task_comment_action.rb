class TaskCommentAction < CommunicationAction
  validates :task_definition, presence: true
  validates :body, presence: true
end
