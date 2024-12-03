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
    has_many :chip_usage_analytics, class_name: 'ChipUsageAnalytics', dependent: :destroy

    def parent_chip_must_be_a_group_chip
      if parent_chip.present? && parent_chip.type != "FeedbackGroupChip"
        errors.add(:parent_chip, "must be a group chip")
      end
    end

    def track_usage_by(tutor)
      analytics = chip_usage_analytics.find_or_initialize_by(tutor: tutor)
      analytics.usage_count += 1
      analytics.save
    end

  end
end
