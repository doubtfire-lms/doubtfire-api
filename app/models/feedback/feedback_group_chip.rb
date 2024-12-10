module Feedback
  class FeedbackGroupChip < FeedbackChip
    belongs_to :learning_outcome

    def serialize
      super.merge({
      })
    end
  end
end
