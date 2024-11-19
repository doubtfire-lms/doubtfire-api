class FeedbackTemplateChip < FeedbackChip
  validates :abbreviation, presence: true
  validates :order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :chip_text, length: { maximum: 20 }
  validates :description
  validates :comment_text
  validates :summary_text
  validates :task_status, presence: true

  validates :order, uniqueness: {
    scope: :task_definition_id,
    message: 'Order must be unique within a task definition'
  }
  validates :order, numericality: {
    greater_than_or_equal_to: 0,
    only_integer: true,
    message: 'Order must be a non-negative integer'
  }
end
