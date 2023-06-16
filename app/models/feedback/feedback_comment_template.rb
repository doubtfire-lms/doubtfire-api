class FeedbackCommentTemplate < ApplicationRecord
  # Associations
  belongs_to :criterion_option

  # Constraints
  validates :comment_text_situation, presence: true
end
