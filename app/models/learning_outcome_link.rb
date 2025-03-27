# == Schema Information
#
# Table name: learning_outcome_links
#
#  id         :bigint           not null, primary key
#  source_id  :bigint           not null
#  target_id  :bigint           not null
#  link_type  :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class LearningOutcomeLink < ApplicationRecord
  belongs_to :source, class_name: 'LearningOutcome'
  belongs_to :target, class_name: 'LearningOutcome'

  validates :source, presence: true
  validates :target, presence: true
  validates :source_id, uniqueness: { scope: :target_id, message: 'Link already exists' }

  validate :validate_link_type
  validate :validate_context

  def validate_link_type
    return if source.nil? || target.nil?

    if source.context_type.nil?
      errors.add(:link_type, 'Cannot link global learning outcomes')
    elsif source.context_type == 'Unit' && target.context_type == 'TaskDefinition'
      errors.add(:link_type, 'Unit learning outcomes may not link to task learning outcomes')
    elsif source.context_type == target.context_type
      errors.add(:link_type, 'Learning outcomes must only link to higher level outcomes')
    end
  end

  def validate_context
    return if source.nil? || target.nil?

    if source.context_type == 'TaskDefinition' && target.context_type == 'Unit' && source.context.unit != target.context
      errors.add(:link_type, 'Task learning outcomes must be linked to the same unit')
    end
  end
end
