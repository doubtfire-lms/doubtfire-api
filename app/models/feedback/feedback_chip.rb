module Feedback
  class FeedbackChip < ApplicationRecord
    self.inheritance_column = :type

    validates :chip_text, presence: true
    validates :description, presence: true

    # validate :parent_chip_must_be_a_group_chip

    belongs_to :parent_chip, class_name: 'FeedbackChip', optional: true
    belongs_to :learning_outcome, class_name: 'LearningOutcome'
    belongs_to :task_status, class_name: 'TaskStatus', optional: true

    has_many :child_chips, class_name: 'FeedbackChip', foreign_key: 'parent_chip_id'

    def parent_chip_must_be_a_group_chip
      if parent_chip.present? && parent_chip.type != "FeedbackGroupChip"
        errors.add(:parent_chip, "must be a group chip")
      end
    end

  end
end
