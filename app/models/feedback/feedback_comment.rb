class FeedbackComment < TaskComment
  # Associations
  belongs_to :criterion_option

  # Constraints
  validates :comment, presence: true
end
