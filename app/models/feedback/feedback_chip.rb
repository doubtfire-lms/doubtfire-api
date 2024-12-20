module Feedback
  class FeedbackChip < ApplicationRecord
    self.inheritance_column = :type

    validates :chip_text, presence: true
    validates :description, presence: true

    belongs_to :parent_chip, class_name: 'FeedbackChip', optional: true
    belongs_to :learning_outcome, class_name: 'LearningOutcome', optional: true

    has_many :child_chips, class_name: 'FeedbackChip', foreign_key: 'parent_chip_id', dependent: :nullify
    has_many :chip_usage_analytics, class_name: 'ChipUsageAnalytics', dependent: :destroy

    validate :parent_chip_cannot_create_loop, if: :parent_chip_id_changed?
    validate :parent_is_group_chip

    validate :check_learning_outcome_consistency
    # validate :check_single_root_chip_per_learning_outcome # there can be multiple root chips
    validate :check_tree_completeness_per_learning_outcome, on: [:update]
    validate :check_no_orphaned_chips


    def track_usage_by(tutor)
      analytics = chip_usage_analytics.find_or_initialize_by(tutor: tutor)
      analytics.usage_count += 1
      analytics.save
    end

    def children
      FeedbackChip.where(parent_chip_id: self.id, learning_outcome_id: self.learning_outcome_id)
    end

    def serialize
      {
        id: self.id,
        type: feedback_type,
        chip_text: self.chip_text,
        description: self.description,
        parent_chip_id: self.parent_chip_id,
        learning_outcome_id: self.learning_outcome_id
      }
    end

    private

    def feedback_type
      if is_a?(Feedback::FeedbackGroupChip)
        'Group'
      elsif is_a?(Feedback::FeedbackTemplateChip)
        'Template'
      else
        'Something went wrong'
      end
    end

    def parent_is_group_chip
      if parent_chip_id.present?
        parent_chip = FeedbackChip.find_by(id: parent_chip_id)
        if parent_chip && parent_chip.type != 'Feedback::FeedbackGroupChip'
          errors.add(:parent_chip_id, 'must be a group chip')
        end
      end
    end

    def parent_chip_cannot_create_loop
      if parent_chip_id.present? && descendant_of?(parent_chip_id)
        errors.add(:parent_chip_id, 'cannot create a loop')
      end
    end

    def descendant_of?(parent_chip_id)
      current_chip_id = parent_chip_id
      while current_chip_id
        return true if current_chip_id == self.id
        current_chip_id = FeedbackChip.find_by(id: current_chip_id)&.parent_chip_id
      end
    end

    def check_no_orphaned_chips
      if parent_chip_id.present?
        parent_chip = FeedbackChip.find_by(id: parent_chip_id)
        errors.add(:parent_chip_id, 'must exist and be a valid chip') unless parent_chip
      end
    end

    def check_learning_outcome_consistency
      if parent_chip_id.present?
        parent_chip = FeedbackChip.find_by(id: parent_chip_id)
        if parent_chip.learning_outcome_id != self.learning_outcome_id
          errors.add(:learning_outcome_id, 'must be consistent with parent chip')
        end
      end
    end

=begin
    def check_single_root_chip_per_learning_outcome
      if parent_chip_id.nil? && FeedbackGroupChip.where(learning_outcome_id: self.learning_outcome_id, parent_chip_id: nil).count > 1
        errors.add(:base, 'Only one root chip allowed per learning outcome')
      end
    end
=end

    def check_tree_completeness_per_learning_outcome
      if parent_chip_id.nil?
        reachable_chips = reachable_chips_from_root
        all_chips_for_learning_outcome = FeedbackGroupChip.where(learning_outcome_id: self.learning_outcome_id)
        if reachable_chips.count != all_chips_for_learning_outcome.count
          errors.add(:base, 'Tree is not complete for the learning outcome; some chips are orphaned and unreachable')
        end
      end
    end

    def reachable_chips_from_root
      visited = Set.new
      stack = [self]

      while stack.any?
        chip = stack.pop
        next if visited.include?(chip)
        visited.add(chip)
        stack.push(*chip.children)
      end
      visited.to_a
    end

  end
end
