class TaskCommentAction < CommunicationAction
  validates :body, presence: true
end
