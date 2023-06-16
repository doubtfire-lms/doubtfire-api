class Criterion < ApplicationRecord
  # Associations
  belongs_to :stage
  has_many :criterion_options, dependent: :destroy

  # Constraints
  validates_associated :stage
  validates :order, :description, presence: true
  validates :order, numericality: {
    greater_than_or_equal_to: 0, only_integer: true,
    message: "order number of criterion option must be a positive integer"
  }
  validates :description, :order, uniqueness: {
    scope: :stage_id,
    message: "description must be unique within this stage"
  }
end
