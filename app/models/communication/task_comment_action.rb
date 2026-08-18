class TaskCommentAction < CommunicationAction
  validates :task_definition, presence: true, unless: :unresolved_reference?
  validates :body, presence: true
end
