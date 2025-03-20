module Feedback
  class ChipUsage < ApplicationRecord
    belongs_to :feedback_chip, class_name: 'FeedbackChip'
    belongs_to :tutor, class_name: 'User'

    validates :usage_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  end
end
