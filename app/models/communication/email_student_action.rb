class EmailStudentAction < CommunicationAction
  validates :subject, presence: true
  validates :body, presence: true
end
