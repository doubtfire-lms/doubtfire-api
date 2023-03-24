class FeedbackCommentTemplate < ApplicationRecord
  # Associations
  # belongs_to :stage -- other direction
  belongs_to :criterion_option

  # Constraints
  validates :comment_text_situation, presence: true
end
