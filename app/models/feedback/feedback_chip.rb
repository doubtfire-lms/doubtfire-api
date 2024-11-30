module Feedback
  class FeedbackChip < ApplicationRecord
    self.inheritance_column = :type

    validates :chip_text, presence: true
    validates :description, presence: true
    validates :section, presence: true # removed

    belongs_to :parent_chip, class_name: 'FeedbackChip', optional: true

    # related entity (task definition, unit, course, null)
    # section (welcome, learning outcomes, integrity, wrap up)
  end
end
