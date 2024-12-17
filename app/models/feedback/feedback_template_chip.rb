module Feedback
  class FeedbackTemplateChip < FeedbackChip
    validates :comment_text, presence: true
    validates :summary_text, presence: true

    validates :parent_chip_id, presence: true # template chips require a parent chip

    def serialize
      super.merge({
        comment_text: self.comment_text,
        summary_text: self.summary_text
      })
    end
  end
end
