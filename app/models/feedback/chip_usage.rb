# == Schema Information
#
# Table name: chip_usages
#
#  id               :bigint           not null, primary key
#  feedback_chip_id :bigint           not null
#  tutor_id         :bigint           not null
#  usage_count      :integer          default(0), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
module Feedback
  class ChipUsage < ApplicationRecord
    belongs_to :feedback_chip, class_name: 'FeedbackChip'
    belongs_to :tutor, class_name: 'User'

    validates :usage_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  end
end
