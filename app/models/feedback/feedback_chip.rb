class FeedbackChip < ApplicationRecord
  self.inheritance_column = :type

  has_many :child_chips, class_name: 'FeedbackChip', foreign_key: 'parent_chip_id'
  belongs_to :parent_chip, class_name: 'FeedbackChip', optional: true
end
