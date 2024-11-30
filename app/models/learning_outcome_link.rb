class LearningOutcomeLink < ApplicationRecord
  belongs_to :source, class_name: 'LearningOutcome'
  belongs_to :target, class_name: 'LearningOutcome'

  validates :source_id, uniqueness: { scope: :target_id, message: 'Link already exists' }
end
