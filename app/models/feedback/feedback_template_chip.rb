module Feedback
  class FeedbackTemplateChip < FeedbackChip
    validates :comment_text, presence: true
    validates :summary_text, presence: true
    # validates :parent_chip_id, presence: true # template chips require a parent chip
  end
end
