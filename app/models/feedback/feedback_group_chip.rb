# == Schema Information
#
# Table name: feedback_chips
#
#  id                  :bigint           not null, primary key
#  type                :string(255)
#  chip_text           :text(65535)
#  description         :text(65535)
#  comment_text        :text(65535)
#  summary_text        :text(65535)
#  learning_outcome_id :bigint           not null
#  parent_chip_id      :bigint
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  task_status         :string(255)
#
module Feedback
  class FeedbackGroupChip < FeedbackChip

    def serialize
      super.merge({
      })
    end
  end
end
