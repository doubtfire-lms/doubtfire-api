module Feedback
  class FeedbackTemplateChip < FeedbackChip
    validates :comment_text, presence: true
    validates :summary_text, presence: true

    validates :parent_chip_id, presence: true # template chips require a parent chip
    belongs_to :task_status, class_name: 'TaskStatus', optional: true
    before_save :set_task_status_name

    def serialize
      super.merge({
        task_status: self.task_status,
        comment_text: self.comment_text,
        summary_text: self.summary_text
      })
    end

    private

    def set_task_status_name
      self.task_status = task_status&.name
    end
  end
end
