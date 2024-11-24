module Feedback
  class FeedbackTemplateChip < FeedbackChip
    validates :comment_text, presence: true
    validates :summary_text, presence: true
  end
end
