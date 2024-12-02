module Feedback
  class FeedbackChip < ApplicationRecord
    self.inheritance_column = :type

    validates :chip_text, presence: true
    validates :description, presence: true

    belongs_to :parent_chip, class_name: 'FeedbackChip', optional: true
    belongs_to :learning_outcome, class_name: 'LearningOutcome'

    has_many :child_chips, class_name: 'FeedbackChip', foreign_key: 'parent_chip_id'
  end
end
