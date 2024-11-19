class FeedbackGroupChip < FeedbackChip
  validates :title, presence: true
  validates :parent_chip_id, presence: true
  validates :child_chip_id, presence: true
  validates :belongs_to, presence: true
  validates :belongs_to_tlo, presence: true

  belongs_to :task_definition
  belongs_to :learning_outcome
end
