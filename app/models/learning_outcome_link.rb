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

  validates :source_id, uniqueness: { scope: :target_id, message: 'Link already exists' }
end
