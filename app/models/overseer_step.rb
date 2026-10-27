class OverseerStep < ApplicationRecord
  belongs_to :task_definition, optional: false

  validates :name, :display_name, :step_type, presence: true
  validates :timeout, presence: true, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 300, message: 'must be between 1 and 300' }
  validates :sort_order, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
