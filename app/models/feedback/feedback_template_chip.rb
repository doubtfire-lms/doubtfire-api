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
  class FeedbackTemplateChip < FeedbackChip
    validates :comment_text, presence: true
    validates :summary_text, presence: true

    # validates :parent_chip_id, presence: true # template chips require a parent chip

    def serialize
      super.merge({
        task_status: self.task_status,
        comment_text: self.comment_text,
        summary_text: self.summary_text
      })
    end

  end
end
