class FeedbackComment < TaskComment
  # Associations
  belongs_to :criterion_option

  # Constraints
  validates :comment_text, presence: true
end
